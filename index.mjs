import { loadStdlib } from '@reach-sh/stdlib';
import * as backend from './build/index.main.mjs';
const stdlib = loadStdlib(process.env);

const startingBalance = stdlib.parseCurrency(100);

const accAlice = await stdlib.newTestAccount(startingBalance);
console.log('Hello, Alice!');

console.log('Launching...');
const ctcAlice = accAlice.contract(backend);
const APIs = [];

const start = async () => {

  const runAPIs = async (who) => {
    const num = Math.floor(Math.random() * 50) + 1;
    const acc = await stdlib.newTestAccount(startingBalance);
    acc.setDebugLabel(who);
    APIs.push([who, acc]);

    const ctc = acc.contract(backend, ctcAlice.getInfo());

    try {
      console.log(`${who} paid ${num}`);
      await ctc.apis.Voters.contribute(stdlib.parseCurrency(num))
    }
    catch (error) {
      console.log(`Sorry ${who}, your contribution was not accepted`);
    }
  };

  await runAPIs('Emmanuel')
  await runAPIs('Michael')
  await runAPIs('Owolabi')
};

console.log('Starting backends...');
await Promise.all([
  backend.Deployer(ctcAlice, {
    ...stdlib.hasRandom,
    start: () => { start(); },
    refund: () => {
      console.log(`Initiating refund`);
    },
    cashOut: () => {
      console.log(`The Deployer cashed out`);
    }
    // implement Alice's interact object here
  }),
]);

const bal = await stdlib.balanceOf(accAlice);
console.log(`The deployer now has ${stdlib.formatCurrency(bal, 4)} ${stdlib.standardUnit}`);
for (const [who, acc] of APIs) {
  const bal = await stdlib.balanceOf(acc);
  console.log(`${who} now has ${stdlib.formatCurrency(bal, 4)} ${stdlib.standardUnit}`);
}
console.log('Goodbye, Alice!');
