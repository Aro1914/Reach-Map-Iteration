/* eslint-disable eqeqeq */
/* eslint-disable no-undef */
"reach 0.1";

export const main = Reach.App(() => {
  setOptions({ untrustworthyMaps: true });

  const Deployer = Participant("Deployer", {
    ...hasRandom,
    start: Fun([], Null),
    refund: Fun([], Null), // Simply notifies the frontend that a refund is about to be initiated
    cashOut: Fun([], Null), // Simply notifies the frontend that the Deployer is about cash out the contract's balance
  });

  const Voters = API("Voters", {
    contribute: Fun([UInt], Null),
  });
  init();
  Deployer.publish();
  commit();
  Deployer.publish();
  const contributors = new Map( // Please note that UInt key types are not supported by the Algorand Network
    UInt, Object({
      address: Address,
      amt: UInt,
    })
  );
  Deployer.interact.start();
  commit();
  Deployer.publish();

  const end = lastConsensusTime() + 20;

  const isValid = false; // Switch this value to either refund or cash out all paid funds; true catches out, false refunds

  const [count, currentBal, keepGoing, lastAddress] = parallelReduce([1, balance(), true, Deployer])
    .invariant(balance() == currentBal) // Edit this to suit the flow of your DApp
    .while(lastConsensusTime() <= end && keepGoing) // This could be a timeout value, edit this to your liking
    .api_(Voters.contribute, (amt) => {
      check(amt > 0, "Contribution too small");
      const payment = amt; // This is amount to be paid to the contract
      return [payment, (notify) => { // In the first index of the return, the payment is transferred to the contract (This could be non-network tokens too)
        notify(null);
        contributors[count] = { address: this, amt: amt };
        return [count + 1, balance(), (count + 1) <= 3 ? keepGoing : false, this]; // Review carefully how you would want to update the while condition, in this case the condition states that the loop continues till 20 blocks after the last consensus time and as long as keepGoing is true
      }];
    })
    .timeout(absoluteTime(end), () => {
      Deployer.publish();
      // Additional functionality could be added to this block, but keep in mind that it will only be executed in a timeout; in this case if keepGoing is updated to false before the timeout, this block would not run
      return [count, currentBal, false, lastAddress];
    });
  if (isValid) { // A condition to decide if a refund is to be carried out or the Deployer cashes out the contract's balance
    Deployer.interact.cashOut();
    transfer(balance()).to(Deployer); // A cash out occurs
  } else {
    Deployer.interact.refund();
    // The entire logic for a refund, only compatible on the ETH network for now, until an alternative can be derived for UInt Map keys
    const fromMap = (m) => fromMaybe(m, (() => ({ address: lastAddress, amt: 0 })), ((x) => x)); // This utility function retrieves the actual value in a Map reference if there is a value
    // Note this function must be customized to the conform to structure of the values held in the Map reference, if the Map holds just a UInt in its value then the return for the None block must be a UInt; in this case the return for the None block is an object of an address of the last API caller and an amount of zero
    var [newCount, currentBalance] = [count, balance()];
    invariant(balance() == currentBalance);
    while (newCount >= 1) {
      commit();
      Deployer.publish();
      if (balance() >= fromMap(contributors[newCount]).amt) { // Guard to ensure that there is sufficient balance in the contract to carry out the transfer
        transfer(fromMap(contributors[newCount]).amt).to(
          fromMap(contributors[newCount]).address
        ); // The refund
      }
      [newCount, currentBalance] = [newCount - 1, balance()];
      continue;
    }
  }
  transfer(balance()).to(Deployer); // In the event the contract was not emptied before this point, the balance goes to the deployer 
  commit();
  exit();
});
