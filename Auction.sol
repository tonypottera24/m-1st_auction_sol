// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.7.0;
pragma experimental ABIEncoderV2;

import {BigNumber} from "./lib/BigNumber.sol";
import {BigNumberLib} from "./lib/BigNumberLib.sol";
import {
    Auctioneer,
    AuctioneerList,
    AuctioneerListLib
} from "./lib/AuctioneerListLib.sol";
import {Bidder, BidderList, BidderListLib} from "./lib/BidderListLib.sol";
import {Ct, CtLib} from "./lib/CtLib.sol";
import {DLProof, DLProofLib} from "./lib/DLProofLib.sol";
import {SameDLProof, SameDLProofLib} from "./lib/SameDLProofLib.sol";
import {CtSameDLProof, CtSameDLProofLib} from "./lib/CtSameDLProofLib.sol";
import {Bid01Proof, Bid01ProofLib} from "./lib/Bid01ProofLib.sol";
import {Timer, TimerLib} from "./lib/TimerLib.sol";

contract Auction {
    using BigNumberLib for BigNumber.instance;
    using AuctioneerListLib for AuctioneerList;
    using BidderListLib for BidderList;
    using CtLib for Ct;
    using CtLib for Ct[];
    using DLProofLib for DLProof;
    using DLProofLib for DLProof[];
    using SameDLProofLib for SameDLProof;
    using SameDLProofLib for SameDLProof[];
    using CtSameDLProofLib for CtSameDLProof;
    using CtSameDLProofLib for CtSameDLProof[];
    using Bid01ProofLib for Bid01Proof;
    using Bid01ProofLib for Bid01Proof[];
    using TimerLib for Timer;

    address payable sellerAddr;

    AuctioneerList aList;

    function getElgamalY() public view returns (BigNumber.instance[2] memory) {
        return [aList.get(0).elgamalY, aList.get(1).elgamalY];
    }

    BidderList bList;

    function getBListLength() public view returns (uint256) {
        return bList.length();
    }

    function getBidProd() public view returns (Ct[] memory) {
        Ct[] memory result = new Ct[](bList.length());
        for (uint256 i = 0; i < bList.length(); i++) {
            result[i] = bList.get(i).bidProd;
        }
        return result;
    }

    function getBidderBid01ProofU(uint256 index)
        public
        view
        returns (Ct[] memory, Ct[] memory)
    {
        Ct[] memory ctU = new Ct[](bList.get(index).bid01Proof.length);
        Ct[] memory ctUU = new Ct[](bList.get(index).bid01Proof.length);
        for (uint256 j = 0; j < bList.get(index).bid01Proof.length; j++) {
            ctU[j] = bList.get(index).bid01Proof[j].u;
            ctUU[j] = bList.get(index).bid01Proof[j].uu;
        }
        return (ctU, ctUU);
    }

    function getBidderBid01ProofV(uint256 index)
        public
        view
        returns (Ct[] memory, Ct[] memory)
    {
        Ct[] memory ctV = new Ct[](bList.get(index).bid01Proof.length);
        Ct[] memory ctVV = new Ct[](bList.get(index).bid01Proof.length);
        for (uint256 j = 0; j < bList.get(index).bid01Proof.length; j++) {
            ctV[j] = bList.get(index).bid01Proof[j].v;
            ctVV[j] = bList.get(index).bid01Proof[j].vv;
        }
        return (ctV, ctVV);
    }

    Ct[] bidC;
    Bid01Proof[] bidC01Proof;

    function getBidC01ProofU() public view returns (Ct[] memory, Ct[] memory) {
        Ct[] memory ctU = new Ct[](bidC01Proof.length);
        Ct[] memory ctUU = new Ct[](bidC01Proof.length);
        for (uint256 j = 0; j < bidC01Proof.length; j++) {
            ctU[j] = bidC01Proof[j].u;
            ctUU[j] = bidC01Proof[j].uu;
        }
        return (ctU, ctUU);
    }

    function getBidC01ProofJV() public view returns (Ct memory, Ct memory) {
        return (
            bidC01Proof[secondHighestBidPriceJ].v,
            bidC01Proof[secondHighestBidPriceJ].vv
        );
    }

    function getBidA() public view returns (Ct[] memory) {
        Ct[] memory result = new Ct[](bList.length());
        for (uint256 i = 0; i < bList.length(); i++) {
            result[i] = bList.get(i).bidA[secondHighestBidPriceJ + 1];
        }
        return result;
    }

    uint256 public binarySearchL;
    uint256 public secondHighestBidPriceJ;
    uint256 public binarySearchR;
    uint256 public winnerI;

    BigNumber.instance public p;
    BigNumber.instance public q;
    BigNumber.instance public g;
    BigNumber.instance public z;
    BigNumber.instance public zInv;
    uint256[] price;

    function getPrice() public view returns (uint256[] memory) {
        return price;
    }

    uint256 public auctioneerBalanceLimit;
    uint256 public bidderBalanceLimit;

    bool public auctionAborted;

    Timer[6] timer;

    function getTimer() public view returns (Timer[6] memory) {
        return timer;
    }

    function hashTest(BigNumber.instance memory a, BigNumber.instance memory b)
        public
        pure
        returns (BigNumber.instance memory)
    {
        bytes32 digest = keccak256(abi.encodePacked(a.val, b.val));
        uint256 bit_length = 0;
        for (uint256 i = 0; i < 256; i++) {
            if (digest >> i > 0) bit_length++;
            else break;
        }
        return BigNumber.instance(abi.encodePacked(digest), false, bit_length);
    }

    constructor(
        address payable[2] memory auctioneer_addr,
        address payable _sellerAddr,
        uint256[] memory _price,
        uint256[6] memory duration,
        uint256[2] memory _balanceLimit
    ) public {
        // 1024 bit
        p = BigNumber.instance(
            hex"e6eae100576ae255abcc28ad5702afdf3713109933cc809d106aa87a26a975914b5d4763bff62b718b122072b50023b3d12be2d90f8203fd30ed2051fa8faa959117097e284cc81e8e0c4c015524ed3eef7bf1feaedaf43ba08ef2f85f930e6851d9f4a7c89192953c6aff6afdb24daf44a39f0e63727c45c72317fe50e61f0f",
            false,
            1024
        );
        q = BigNumber.instance(
            hex"737570802bb5712ad5e61456ab8157ef9b89884c99e6404e8835543d1354bac8a5aea3b1dffb15b8c58910395a8011d9e895f16c87c101fe98769028fd47d54ac88b84bf1426640f47062600aa92769f77bdf8ff576d7a1dd047797c2fc9873428ecfa53e448c94a9e357fb57ed926d7a251cf8731b93e22e3918bff28730f87",
            false,
            1023
        );
        // 2048 bit
        // p = BigNumber.instance(
        //     hex"913e12504b80d82c6819e21fa7fa53cdb0583a9ff5d46ba805b33abe417c398a5ac4a874ce894faee67180a5ff8d14caeb2ff602af9f3739ca12680b67d7d78c6ff48b77e1a7cfc6d0ea2e53cdcb77e90970ebb5c26a14fe9ed84b9f486961186347f60fe74fc0681610b404f7ad9bb8f26de73b4b42ea037cf5d24d9545020726207373ae75b05157776387d592c6fc0005d9aa617283da410e26244424151f56b3b486548fe59a3245fe57f5f16aafbbb17fa7401186a7afd80add3f33c4c505a1b8f6c2ae71269171f10e8fa9fbf929b201abae5b20548339049ff147ba799a037d3fc854e5608418269788cbf9a8a4e6c33343bfcdbb3f03e80aef72525f",
        //     false,
        //     2048
        // );
        // q = BigNumber.instance(
        //     hex"489f092825c06c16340cf10fd3fd29e6d82c1d4ffaea35d402d99d5f20be1cc52d62543a6744a7d77338c052ffc68a657597fb0157cf9b9ce5093405b3ebebc637fa45bbf0d3e7e368751729e6e5bbf484b875dae1350a7f4f6c25cfa434b08c31a3fb07f3a7e0340b085a027bd6cddc7936f39da5a17501be7ae926caa28103931039b9d73ad828abbbb1c3eac9637e0002ecd530b941ed2087131222120a8fab59da432a47f2cd1922ff2bfaf8b557ddd8bfd3a008c353d7ec056e9f99e26282d0dc7b6157389348b8f88747d4fdfc94d900d5d72d902a419c824ff8a3dd3ccd01be9fe42a72b0420c134bc465fcd452736199a1dfe6dd9f81f40577b9292f",
        //     false,
        //     2047
        // );
        // 3072 bit
        // p = BigNumber.instance(
        //     hex"f9c610b2c0cd225ba3b96eaa3f3aaaa8ab87fc992e5fb4629fc9d6ddeeaefd24d003a3f6ef0dd2ade5d4cf44c8e9b991140409afde3f6b7a20046ddf519548bbefdbf6b7a053c035d3d8f0baf04baa5498c60d573eea51441a9b2886536745873165d7211b98a1ff4c71ecbf5430c0490e196e0bfa751cbfc7532e1d032283aeaf8bd844181945a064d3ec36794462ece2799f7397363f6e8095ed21fe322a50a317e6045e8cbef654086e4b433b766248f429660fbd1504591ca8876f4e2bb39e5e21ef14d7aaedb257931abda891b151211c3d4699bb0a3ee9276c75312dd033f7a6518bdf8f5dce3699bb24e0f73baf3b6a79231e833e779a314424de2cf210f2a5292ac2b50ac383c3f290eeb6edffcfd0220d6f9db9317a9bbbad8526d25124ba4b9ad42c0154c9a061e324a87fc580157f8d3a1dee5e8856881ba8c40195fafce21dff72e548b9ad9bfe8fb8d54a250be28bd7bbbe85307725c6d981ff188a6625ab651472c4363a7f750a32b1cee27a7eeee8ed8cdcae6b8dbadbf0ff",
        //     false,
        //     3072
        // );
        // q = BigNumber.instance(
        //     hex"7ce308596066912dd1dcb7551f9d555455c3fe4c972fda314fe4eb6ef7577e926801d1fb7786e956f2ea67a26474dcc88a0204d7ef1fb5bd100236efa8caa45df7edfb5bd029e01ae9ec785d7825d52a4c6306ab9f7528a20d4d944329b3a2c398b2eb908dcc50ffa638f65faa186024870cb705fd3a8e5fe3a9970e819141d757c5ec220c0ca2d03269f61b3ca23176713ccfb9cb9b1fb7404af690ff191528518bf3022f465f7b2a043725a19dbb31247a14b307de8a822c8e5443b7a715d9cf2f10f78a6bd576d92bc98d5ed448d8a8908e1ea34cdd851f7493b63a9896e819fbd328c5efc7aee71b4cdd92707b9dd79db53c918f419f3bcd18a2126f16790879529495615a8561c1e1f948775b76ffe7e81106b7cedc98bd4dddd6c2936928925d25cd6a1600aa64d030f192543fe2c00abfc69d0ef72f442b440dd46200cafd7e710effb972a45cd6cdff47dc6aa51285f145ebdddf42983b92e36cc0ff8c453312d5b28a39621b1d3fba851958e7713d3f777476c66e5735c6dd6df87f",
        //     false,
        //     3071
        // );
        g = BigNumber.instance(
            hex"0000000000000000000000000000000000000000000000000000000000000002",
            false,
            2
        );
        z = BigNumber.instance(
            hex"0000000000000000000000000000000000000000000000000000000000000003",
            false,
            2
        );
        // 1024
        zInv = BigNumber.instance(
            hex"4cf8f5aac7ce4b71e3eeb839c7ab8ff5125bb03311442adf0578e2d362387c85c3c9c27695520e7b2e5b60263c55613bf063f6485a80abff104f0ac5fe2fe387305d032a0d6eed5f84aec40071b6f9bfa52950aa3a48fc13e02fa652ca865a22c5f3518d42db30dc6978ffce5490c48fc18bdfaf767b7ec1ed0bb2aa1af75fb0",
            false,
            1023
        );
        // zInv = BigNumber.instance(
        //     hex"306a061ac3d59d6422b34b5fe2a8c699e572be3551f1793801e668ea15d4132e1e418d7c44d86fe4f77b2ae1ffd9b198f90ffcab8fdfbd13435b7803cd47f284255183d2a08d454245a364c699ee7d4dadd04e91eb78b1aa34f2c3dfc2cdcb082117fcaff7c54022b2059156fd39de92fb79f7be6e6ba3567efc9b6f31c1ab57b760267be4d1e570727d212d4730ecfeaaac9de375d0d69e15af620c16b6b1b51ce691821c2ff733661754c7fca5ce3a93e5d537c005d78d3a9d58f46a6696ec5735e85240e4d062307b505a2fe353fdb890ab393a1e601c2bbdac35506d3e2888abd46a981c4c75815d623282eea88d8c4cebbbc13fef3e6a56a2ae4fd0c620",
        //     false,
        //     2046
        // );
        // zInv = BigNumber.instance(
        //     hex"53420590eaef0b73e13dcf8e15138e38392d54330f753c20dfedf249fa3a54619aabe1524faf4639f746efc1984de885b156ade54a1523d3600179f51b31c2e94ff3fce7e01beabc9bf2fae8fac3e371884204726a4e1b16b3890d821bcd172d107747b5b3dd8b55197b4eea7165956daf5dcf59537c5eea97c664b45660d68f8fd94816b2b3173576f14ebcd316cba44b7ddfd132676a7a2adca460aa10b8c58bb2a20174d994fcc6ad7a191669277618516322053f070173098d827a6f63e68a1f60a506f28e4f3b72865e3f38309070605ebf178893ae14f862797c65b9f011528cc5d94a851f44bcdde90c4afd13e513ce28610a2bbf7d3365c1619f6450b050e1b863963c58ebd696a6304f924f55454560af253493107e33e939d70cf0c5b6e8c3de46b955c6ede020a10c382a972ab1d52f135f4f74d81cd809384155dca8fef609ffd0f7183de48954da92f1c361aea0d947e93f81bad261ecf32b55082e220c8e7706d0ec12137fd1ae10e5efa0d37fa4f84f2ef43a23d9e8f3fb00",
        //     false,
        //     3071
        // );
        assert(z.mul(zInv, p).isOne(p));
        require(
            auctioneer_addr[0] != auctioneer_addr[1],
            "Auctioneer address must be same."
        );
        for (uint256 i = 0; i < 2; i++) {
            require(
                auctioneer_addr[i] != address(0),
                "Auctioneer address must not be zero."
            );
            aList.add(auctioneer_addr[i]);
        }
        require(_sellerAddr != address(0));
        sellerAddr = _sellerAddr;
        require(_price.length != 0, "Price list length must not be 0.");
        price = _price;
        binarySearchR = price.length;
        secondHighestBidPriceJ = (binarySearchL + binarySearchR) / 2;
        for (uint256 i = 0; i < 6; i++) {
            require(duration[i] > 0, "Timer duration must larger than zero.");
            timer[i].duration = duration[i];
        }
        timer[0].start = now;
        auctioneerBalanceLimit = _balanceLimit[0];
        bidderBalanceLimit = _balanceLimit[1];
    }

    function isPhase1() internal view returns (bool) {
        return phase1Success() == false;
    }

    function phase1AuctioneerInit(
        BigNumber.instance memory elgamalY,
        DLProof memory pi
    ) public payable {
        require(isPhase1(), "Phase 0 not completed yet.");
        require(timer[0].timesUp() == false, "Phase 1 time's up.");
        Auctioneer storage auctioneer = aList.find(msg.sender);
        require(
            auctioneer.addr != address(0),
            "Only pre-defined addresses can become auctioneer."
        );
        require(elgamalY.isZero(p) == false, "elgamalY must not be zero");
        require(pi.valid(g, elgamalY, p, q), "Discrete log proof invalid.");
        require(
            msg.value >= auctioneerBalanceLimit,
            "Auctioneer's deposit must larger than auctioneerBalanceLimit."
        );
        auctioneer.elgamalY = elgamalY;
        auctioneer.balance = msg.value;
        if (phase1Success()) {
            timer[1].start = now;
            timer[2].start = timer[1].start + timer[1].duration;
        }
    }

    function phase1Success() public view returns (bool) {
        return
            aList.get(0).elgamalY.isZero(p) == false &&
            aList.get(1).elgamalY.isZero(p) == false;
    }

    function phase1Resolve() public {
        require(auctionAborted == false, "Problem resolved, auction aborted.");
        require(isPhase1(), "Phase 1 completed successfully.");
        require(timer[0].timesUp(), "Phase 1 still have time to complete.");
        if (aList.get(0).elgamalY.isZero(p)) aList.get(0).malicious = true;
        if (aList.get(1).elgamalY.isZero(p)) aList.get(1).malicious = true;
        compensateAuctioneerMalicious();
        auctionAborted = true;
    }

    function isPhase2() internal view returns (bool) {
        return isPhase1() == false && phase2Success() == false;
    }

    function phase2BidderJoin(Ct[] memory bid) public payable {
        require(isPhase2(), "Phase 1 not completed yet.");
        require(timer[1].timesUp() == false, "Phase 2 time's up.");
        require(
            msg.value >= bidderBalanceLimit,
            "Bidder's deposit must larger than bidderBalanceLimit."
        );
        require(
            bid.length == price.length,
            "Bid list's length must equals to bid price list's length."
        );
        require(bid.isNotDec(p), "bid.u1, bid.u2, bid.c must within (0, p)");
        bList.add(msg.sender, msg.value, bid, zInv, p);
    }

    function phase2Success() public view returns (bool) {
        return bList.length() > 1 && timer[1].timesUp();
    }

    function phase2Resolve() public {
        require(auctionAborted == false, "Problem resolved, auction aborted.");
        require(isPhase2(), "Phase 2 completed successfully.");
        require(timer[1].timesUp(), "Phase 2 still have time to complete.");
        returnAllBalance();
        auctionAborted = true;
    }

    function isPhase3() internal view returns (bool) {
        return
            isPhase1() == false &&
            isPhase2() == false &&
            phase3Success() == false;
    }

    function phase3BidderVerificationSum1(
        BigNumber.instance[] memory ux,
        BigNumber.instance[] memory uxInv,
        SameDLProof[] memory pi
    ) public {
        require(isPhase3(), "Phase 3 not completed yet.");
        require(timer[2].timesUp() == false, "Phase 3 time's up.");
        require(
            ux.length == bList.length() && pi.length == bList.length(),
            "Length of bList, ux, pi must be same."
        );
        Auctioneer storage auctioneer = aList.find(msg.sender);
        for (uint256 i = 0; i < bList.length(); i++) {
            require(
                bList.get(i).bidProd.isNotDec(p) ||
                    bList.get(i).bidProd.isPartialDec(p),
                "Ct has already been decrypted."
            );
            bList.get(i).bidProd = bList.get(i).bidProd.decrypt(
                auctioneer,
                ux[i],
                uxInv[i],
                pi[i],
                g,
                p,
                q
            );
        }
        if (phase3Success()) {
            phase4Prepare();
            timer[3].start = now;
        }
    }

    function phase3BidderVerification01Omega(
        Ct[][] memory ctV,
        Ct[][] memory ctVV,
        CtSameDLProof[][] memory pi
    ) public {
        require(isPhase3(), "Phase 3 not completed yet.");
        require(timer[2].timesUp() == false, "Phase 3 time's up.");
        require(
            ctV.length == bList.length() &&
                ctVV.length == bList.length() &&
                pi.length == bList.length(),
            "Length of bList, ctV, ctVV, pi must be same."
        );
        require(
            msg.sender == aList.get(1).addr,
            "Only A2 can call this function."
        );
        for (uint256 i = 0; i < bList.length(); i++) {
            bList.get(i).bid01Proof.setV(ctV[i], ctVV[i], pi[i], p, q);
        }
    }

    function phase3BidderVerification01Dec(
        BigNumber.instance[][] memory uxV,
        BigNumber.instance[][] memory uxVInv,
        SameDLProof[][] memory piV,
        BigNumber.instance[][] memory uxVV,
        BigNumber.instance[][] memory uxVVInv,
        SameDLProof[][] memory piVV
    ) public {
        require(isPhase3(), "Phase 3 not completed yet.");
        require(timer[2].timesUp() == false, "Phase 3 time's up.");
        require(
            uxV.length == bList.length() &&
                uxVInv.length == bList.length() &&
                piV.length == bList.length() &&
                uxVV.length == bList.length() &&
                uxVV.length == bList.length() &&
                piVV.length == bList.length(),
            "Length of bList, uxV, uxVV, pi must be same."
        );
        Auctioneer storage auctioneer = aList.find(msg.sender);
        for (uint256 i = 0; i < bList.length(); i++) {
            require(
                bList.get(i).bid01Proof.length > 0,
                "bList.get(i).bid01Proof is empty."
            );
            bList.get(i).bid01Proof.setA(
                auctioneer,
                uxV[i],
                uxVInv[i],
                piV[i],
                g,
                p,
                q
            );
            bList.get(i).bid01Proof.setAA(
                auctioneer,
                uxVV[i],
                uxVVInv[i],
                piVV[i],
                g,
                p,
                q
            );
        }
        if (phase3Success()) {
            phase4Prepare();
            timer[3].start = now;
        }
    }

    function phase3Success() public view returns (bool) {
        for (uint256 i = 0; i < bList.length(); i++) {
            if (
                bList.get(i).bidProd.isFullDec(p) == false ||
                bList.get(i).bidProd.c.equals(z, p) == false ||
                bList.get(i).bid01Proof.length == 0 ||
                (bList.get(i).bid01Proof.length > 0 &&
                    bList.get(i).bid01Proof.valid(p) == false)
            ) return false;
        }
        return true;
    }

    function phase3Resolve() public {
        require(auctionAborted == false, "Problem resolved, auction aborted.");
        require(isPhase3(), "Phase 3 completed successfully.");
        require(timer[2].timesUp(), "Phase 3 still have time to complete.");
        for (uint256 i = 0; i < bList.length(); i++) {
            if (bList.get(i).bidProd.isDecByA(0, p) == false)
                aList.get(0).malicious = true;
            if (bList.get(i).bidProd.isDecByA(1, p) == false)
                aList.get(1).malicious = true;
            if (bList.get(i).bid01Proof.stageA(p) == false)
                aList.get(1).malicious = true;
            else {
                if (bList.get(i).bid01Proof.stageAIsDecByA(0, p) == false)
                    aList.get(0).malicious = true;
                if (bList.get(i).bid01Proof.stageAIsDecByA(1, p) == false)
                    aList.get(1).malicious = true;
            }
            if (aList.get(0).malicious && aList.get(1).malicious) break;
        }
        if (aList.malicious()) {
            compensateAuctioneerMalicious();
            auctionAborted = true;
        } else {
            for (uint256 i = 0; i < bList.length(); i++) {
                assert(bList.get(i).bidProd.isFullDec(p));
                if (bList.get(i).bidProd.c.equals(z, p) == false) {
                    bList.get(i).malicious = true;
                    continue;
                }
                assert(bList.get(i).bid01Proof.stageACompleted(p));
                if (bList.get(i).bid01Proof.valid(p) == false)
                    bList.get(i).malicious = true;
            }
            if (bList.malicious()) {
                compensateBidderMalicious();
                bList.removeMalicious();
            }
            if (bList.length() > 0) {
                phase4Prepare();
                timer[3].start = now;
            } else {
                returnAllBalance();
                auctionAborted = true;
            }
        }
    }

    function phase4Prepare() internal {
        require(isPhase4(), "Phase 4 not completed yet.");
        for (uint256 j = 0; j < price.length; j++) {
            Ct memory ct = bList.get(0).bidA[j];
            for (uint256 i = 1; i < bList.length(); i++) {
                ct = ct.mul(bList.get(i).bidA[j], p);
            }
            bidC.push(ct);
            bidC01Proof.push();
        }
        bidC01Proof.setU(bidC, zInv, p);
    }

    function isPhase4() internal view returns (bool) {
        return
            isPhase1() == false &&
            isPhase2() == false &&
            isPhase3() == false &&
            phase4Success() == false;
    }

    function phase4SecondHighestBidDecisionOmega(
        Ct[] memory ctV,
        Ct[] memory ctVV,
        CtSameDLProof[] memory pi
    ) public {
        require(isPhase4(), "Phase 4 not completed yet.");
        require(timer[3].timesUp() == false, "Phase 4 time's up.");
        require(
            ctV.length == bidC01Proof.length &&
                ctVV.length == bidC01Proof.length &&
                pi.length == bidC01Proof.length,
            "Length of bidC01Proof, ctV, ctVV, pi must be same."
        );
        require(
            msg.sender == aList.get(1).addr,
            "Only A2 can call this function."
        );
        bidC01Proof.setV(ctV, ctVV, pi, p, q);
    }

    function phase4SecondHighestBidDecisionDec(
        BigNumber.instance memory uxV,
        BigNumber.instance memory uxVInv,
        SameDLProof memory piV,
        BigNumber.instance memory uxVV,
        BigNumber.instance memory uxVVInv,
        SameDLProof memory piVV
    ) public {
        require(isPhase4(), "Phase 4 not completed yet.");
        require(timer[3].timesUp() == false, "Phase 4 time's up.");
        Auctioneer storage auctioneer = aList.find(msg.sender);
        bidC01Proof[secondHighestBidPriceJ].setA(
            auctioneer,
            uxV,
            uxVInv,
            piV,
            g,
            p,
            q
        );
        bidC01Proof[secondHighestBidPriceJ].setAA(
            auctioneer,
            uxVV,
            uxVVInv,
            piVV,
            g,
            p,
            q
        );

        if (bidC01Proof[secondHighestBidPriceJ].stageACompleted(p)) {
            if (bidC01Proof[secondHighestBidPriceJ].valid(p)) {
                binarySearchR = secondHighestBidPriceJ;
            } else {
                binarySearchL = secondHighestBidPriceJ;
            }
            secondHighestBidPriceJ = (binarySearchL + binarySearchR) / 2;
        }
        if (phase4Success()) timer[4].start = now;
    }

    function phase4Success() public view returns (bool) {
        if (binarySearchL == price.length - 1) return false;
        return binarySearchL + 1 == binarySearchR;
    }

    function phase4Resolve() public {
        require(auctionAborted == false, "Problem resolved, auction aborted.");
        require(isPhase4(), "Phase 4 completed successfully.");
        require(timer[3].timesUp(), "Phase 4 still have time to complete.");
        if (bidC01Proof.stageA(p) == false) {
            aList.get(1).malicious = true;
        } else {
            if (bidC01Proof.stageAIsDecByA(0, p) == false)
                aList.get(0).malicious = true;
            if (bidC01Proof.stageAIsDecByA(1, p) == false)
                aList.get(1).malicious = true;
        }
        compensateAuctioneerMalicious();
        auctionAborted = true;
    }

    function isPhase5() public view returns (bool) {
        return
            isPhase1() == false &&
            isPhase2() == false &&
            isPhase3() == false &&
            isPhase4() == false &&
            phase5Success() == false;
    }

    function phase5WinnerDecision(
        BigNumber.instance[] memory ux,
        BigNumber.instance[] memory uxInv,
        SameDLProof[] memory pi
    ) public {
        require(isPhase5(), "Phase 5 not completed yet.");
        require(timer[4].timesUp() == false, "Phase 5 time's up.");
        require(
            ux.length == bList.length() && pi.length == bList.length(),
            "Length of bList, ux, pi must be same."
        );
        Auctioneer storage auctioneer = aList.find(msg.sender);
        for (uint256 i = 0; i < bList.length(); i++) {
            bList.get(i).bidA[secondHighestBidPriceJ + 1] = bList
                .get(i)
                .bidA[secondHighestBidPriceJ + 1]
                .decrypt(auctioneer, ux[i], uxInv[i], pi[i], g, p, q);
            if (
                bList.get(i).bidA[secondHighestBidPriceJ + 1].isFullDec(p) &&
                bList.get(i).bidA[secondHighestBidPriceJ + 1].c.equals(z, p)
            ) {
                winnerI = i;
            }
        }
        if (phase5Success()) timer[5].start = now;
    }

    function phase5Success() public view returns (bool) {
        for (uint256 i = 0; i < bList.length(); i++) {
            if (
                bList.get(i).bidA[secondHighestBidPriceJ + 1].isFullDec(p) &&
                bList.get(i).bidA[secondHighestBidPriceJ + 1].c.isOne(p)
            ) {
                return true;
            }
        }
        return false;
    }

    function phase5Resolve() public {
        require(auctionAborted == false, "Problem resolved, auction aborted.");
        require(isPhase5(), "Phase 5 completed successfully.");
        require(timer[4].timesUp(), "Phase 5 still have time to complete.");
        for (uint256 i = 0; i < bList.length(); i++) {
            if (
                bList.get(winnerI).bidA[secondHighestBidPriceJ + 1].isDecByA(
                    0,
                    p
                ) == false
            ) aList.get(0).malicious = true;
            if (
                bList.get(winnerI).bidA[secondHighestBidPriceJ + 1].isDecByA(
                    1,
                    p
                ) == false
            ) aList.get(1).malicious = true;
            if (aList.get(0).malicious && aList.get(1).malicious) break;
        }
        compensateAuctioneerMalicious();
        auctionAborted = true;
    }

    function isPhase6() internal view returns (bool) {
        return
            isPhase1() == false &&
            isPhase2() == false &&
            isPhase3() == false &&
            isPhase4() == false &&
            isPhase5() == false &&
            phase6Success() == false;
    }

    function phase6Payment() public payable {
        require(isPhase6(), "Phase 6 not completed yet.");
        require(timer[5].timesUp() == false, "Phase 6 time's up.");
        require(
            msg.sender == bList.get(winnerI).addr,
            "Only winner needs to pay."
        );
        require(
            msg.value == price[secondHighestBidPriceJ],
            "msg.value must equals to the second highest price."
        );
        sellerAddr.transfer(msg.value);
        returnAllBalance();
    }

    function getBalance() public view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](
            aList.length() + bList.length()
        );
        for (uint256 i = 0; i < aList.length(); i++) {
            result[i] = aList.get(i).balance;
        }
        for (uint256 i = 0; i < bList.length(); i++) {
            result[i + aList.length()] = bList.get(i).balance;
        }
        return result;
    }

    function phase6Success() public view returns (bool) {
        for (uint256 i = 0; i < aList.length(); i++) {
            if (aList.get(i).balance > 0) return false;
        }
        for (uint256 i = 0; i < bList.length(); i++) {
            if (bList.get(i).balance > 0) return false;
        }
    }

    function phase6Resolve() public {
        require(auctionAborted == false, "Problem resolved, auction aborted.");
        require(isPhase6(), "Phase 6 completed successfully.");
        require(timer[5].timesUp(), "Phase 6 still have time to complete.");
        bList.get(winnerI).malicious = true;
        compensateBidderMalicious();
        bList.removeMalicious();
        returnAllBalance();
        auctionAborted = true;
    }

    function returnAllBalance() internal {
        require(aList.malicious() == false && bList.malicious() == false);
        for (uint256 i = 0; i < aList.length(); i++) {
            if (aList.get(i).balance > 0) {
                aList.get(i).addr.transfer(aList.get(i).balance);
                aList.get(i).balance = 0;
            }
        }
        for (uint256 i = 0; i < bList.length(); i++) {
            if (bList.get(i).balance > 0) {
                bList.get(i).addr.transfer(bList.get(i).balance);
                bList.get(i).balance = 0;
            }
        }
    }

    function compensateAuctioneerMalicious() internal {
        require(aList.malicious(), "Auctioneers are not malicious.");
        uint256 d;
        for (uint256 i = 0; i < aList.length(); i++) {
            if (aList.get(i).malicious) {
                d += aList.get(i).balance;
                aList.get(i).balance = 0;
            }
        }
        if (aList.get(0).malicious && aList.get(1).malicious)
            d /= bList.length();
        else d /= 1 + bList.length();
        for (uint256 i = 0; i < aList.length(); i++) {
            if (aList.get(i).malicious == false) {
                aList.get(i).addr.transfer(d + aList.get(i).balance);
                aList.get(i).balance = 0;
            }
        }
        for (uint256 i = 0; i < bList.length(); i++) {
            bList.get(i).addr.transfer(d + bList.get(i).balance);
            bList.get(i).balance = 0;
        }
    }

    function compensateBidderMalicious() internal {
        require(bList.malicious(), "Bidders are not malicious.");
        uint256 d;
        uint256 maliciousBidderCount;
        for (uint256 i = 0; i < bList.length(); i++) {
            if (bList.get(i).malicious) {
                d += bList.get(i).balance;
                bList.get(i).balance = 0;
                maliciousBidderCount++;
            }
        }
        d /= aList.length() + bList.length() - maliciousBidderCount;
        aList.get(0).addr.transfer(d);
        aList.get(1).addr.transfer(d);
        for (uint256 i = 0; i < bList.length(); i++) {
            if (bList.get(i).malicious == false) bList.get(i).addr.transfer(d);
        }
    }
}
