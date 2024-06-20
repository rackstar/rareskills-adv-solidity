1. How can OpenSea quickly determine which NFTs an address owns if most NFTs don’t use ERC721 enumerable? Explain how you would accomplish this if you were creating an NFT marketplace.

* For every NFT contract address you want to track you we'll set a scanner worker
* We need to track past `transfer` events as well as any future events
* The scanner worker should scan from the inception of the NFT contract and periodically scan for any new ones as blocks are mined
* Index the owners address and update it accordingly based on new `transfer` events
* This will give our market place the update information about owners
* Setup API so the the FE of the market place can query NTF owner information
