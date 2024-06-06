### Why does the SafeERC20 program exist and when should it be used?

SafeERC20 is to protect from the common pitfalls for usings ER20 such as:

* missing boolean return on `transfer`, `transferFrom`, and `approve` functions which can lead to unexpected behaviours
* reverts instead of failing silently if `transfer`, `transferFrom`, and `approve` fails

SafeERC29 should be used when your contract is interacting with ERC20 tokens to help guard against common issues and vulnerabilities with token transfers and approvals