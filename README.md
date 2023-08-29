# Smart Contract based M+1st-Price Sealed-bid Auction

An auction is commonly used to sell limited resources. In the Blockchain related fields, an auction can be applied to NFT, Proof of Stake (PoS), Cross-Chain Communication (CCC) and Decentralized EXchange (DEX). A second-price auction, where the bid price reflects the bidder's idea of value, won the Nobel Prize. In a second-price (sealed-bid) auction, a bidder with the highest bid wins and pays the second-highest price for the goods. Each bidder can only bid once and cannot learn other bidders' bids. Google Ads used a second-price auction but migrated to an English auction because it is not easy to achieve public verifiability on the second price. A second-price auction can be generalized to a M+1st-price auction that sells M goods. The highest M winners pay the M+1st-price.
There are some required properties for a M+1st-price auction.

* Correctness and Public Verifiability: Correctness means the auction protocol can find M winners and the M+1st-price. This result should be publicly verifiable.

* Bid Secrecy: A M+1st-price auction is a sealed-bid auction. All bids are sealed and kept secret.

* M+1st-Bidder's Anonymity: In a M+1st-price auction, the identity of the bidder who bids the M+1st-price should be kept a secret.

We proposed three Smart Contract based auction protocols. All of them fulfill the required properties and provide additional features without a trusted manager.

### Auction Protocol with Exponential Bid Upper Bound (2023)

In the `IEEE-Access` and the `master` branch, we focus on extending the bid upper bound. The time complexity of this protocol is O(M log P) per bidder.
A bit-slice bidding vector V is necessary to compare each bidder's bids secretly without a trusted manager. The upper bound of a bidder's bid is bounded by the length of the bidding vector |V|. In this protocol, we use a base-2 binary format to encode the bidding vector. To our best knowledge, this is the first secure M+1st-price auction protocol that can each an exponential level bid upper bound 2^|V| without a trusted manager, somewhat homomorphic encryption (SHE) and fully homomorphic encryption (FHE). Please read the following [journal paper](https://ieeexplore.ieee.org/abstract/document/10225494) for more details.

> Po-Chu Hsu and Atsuko Miyaji. ``Blockchain based M+1st-Price Auction with Exponential Bid Upper Bound''. In IEEE Access, pages 1–17, 2023

The conference version can be found in the `SciSec2022` branch. Please read the following [conference paper](https://link.springer.com/chapter/10.1007/978-3-031-17551-0_8) for more details.

> Po-Chu Hsu and Atsuko Miyaji. ``Scalable M+1st-Price Auction with Infinite Bidding Price''. In International Conference on Science of Cyber Security (SciSec’22), LNCS 13580, Springer-Verlag, pages 121–136, 2022


### Auction Protocol with Optimal Time Complexity (2022)

In the `TrustCom2021` branch, we focus on optimizing the time complexity. The time complexity of this protocol is O(P) per bidder.
The time complexity for a trusted manager is usually O(BPM) since the manager needs to compare all B bidder's bids, verify each bidder's bidding vector with length P and find M winning bidders.
We use zero-knowledge proofs to remove the B factor and we found a greedy strategy to remove the M factor.
To our best knowledge, this is the first secure M+1st-price auction protocol that can each an optimal time complexity without a trusted manager and Mix and Match protocol. Please read the following [conference paper](https://ieeexplore.ieee.org/abstract/document/9724495/) for more details.

> Po-Chu Hsu and Atsuko Miyaji. ``Bidder Scalable M+1st-Price Auction with Public Verifiability''. In International Conference on Trust, Security and Privacy in Comput- ing and Communications (TrustCom’21), IEEE, pages 34–42, 2021

### Auction Protocol without a Trusted Manager (2021)

In the `DSC2021` branch, we focus on how to use Smart Contracts to replace the trusted manager. The time complexity of this protocol is O(BPM) per bidder.
To our best knowledge, this is the first secure M+1st-price auction protocol that can fulfill all required properties without a trusted manager. Please read the following [journal paper](https://www.hindawi.com/journals/scn/2021/1615117/) for more details.

> Po-Chu Hsu and Atsuko Miyaji. ``Publicly Verifiable M+1st-Price Auction Fit for IoT with Minimum Storage''. In Security and Communication Networks, pages 1–10, 2021

The conference version is the same as the `DSC2021` branch. Please read the following [conference paper](https://ieeexplore.ieee.org/abstract/document/9346242) for more details.

> Po-Chu Hsu and Atsuko Miyaji. ``Verifiable M+1st-Price Auction without Manager''. In Conference on Dependable and Secure Computing (DSC’21), IEEE, pages 1–8, 2021


## Getting Started

### Dependencies

* `python3`
* A virtual execution environment such as `python3-venv` (tested)
* An Ethereum Blockchain simulator such as [ganache-cli](https://github.com/trufflesuite/ganache) (tested)
* A Solidity compiler such as [py-solc-x](https://pypi.org/project/py-solc-x/) (tested)

### Download the repository

The [Python Web3 Client](https://github.com/tonypottera24/m-1st_auction_sol) is designed to work with our [Solidity Smart Contract](https://github.com/tonypottera24/m-1st_auction_sol).

```
git clone git@github.com:tonypottera24/m-1st_auction_py.git
git clone git@github.com:tonypottera24/m-1st_auction_sol.git
cd m-1st_auction_py
```

### Install python virtual environment

```
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Execute the program

1. Start a Blockchain simulator such as [ganache-cli](https://github.com/trufflesuite/ganache). An example setup is as follows.
    ```
    ganache-cli --miner.defaultGasPrice 1 --miner.blockGasLimit 0xfffffffffff --miner.callGasLimit 0xfffffffffff --chain.allowUnlimitedContractSize --logging.debug -a 1000 --port 8546
    ```
1. Install a Solidity compiler such as [py-solc-x](https://pypi.org/project/py-solc-x/). You need to follow the instructions on their website to download the binary.
1. The codes in `contract.py` will use the Solidity compiler downloaded by `py-solc-x` to compile the Smart Contract and deploy the compiled contract to the Ganache simulator.

### Usage

```
usage: main.py [-h] [--port PORT] -M M -B BIDDER -L L
```

* `--port`: the port of the Ethereum simulator RPC
* `-M`: the number of goods the seller wants to sell.
* `-B`: the number of bidders you want to simulate.
* `-L`: the length of the bidding price.

## Contributions

If you have any questions or want to learn more about this research, please open an issue or send a mail to the following address.

* Po-Chu Hsu: tonypottera[at]gmail.com

## License

This project is licensed under the MIT License - see the LICENSE.txt file for details
