1. How does ERC721A save gas?

* Batch NFT minting
* Batch NFT transfers
* More efficient storage
  * slot packing for multiple tokens and 
  * single ownership record if owner owns multiple consecutive tokens

2. Where does it add cost?

* Initial deployment
* Reading of data - the logic to read data could be more complex due to the optimizations for batch operations and compact storage