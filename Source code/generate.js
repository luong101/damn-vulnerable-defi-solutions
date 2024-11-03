const { ethers } = require("ethers");

const key1 = '0x7d15bba26c523683bfc3dc7cdc5d1b8a2744447597cf4da1705cf6c993063744';
const key2 = '0x68bd020ad186b647a691c6a5c0c1529f21ecd09dcc45241402ac60ba377c4159';
var wallet = new ethers.Wallet(key1);

console.log('Address 1:', wallet.address);
wallet = new ethers.Wallet(key2);
console.log('Address 2:', wallet.address);
