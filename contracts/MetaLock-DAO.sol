// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MetaLockDAO is Ownable {
    IERC20 public governanceToken;            // Governance token for voting
    uint256 public proposalCount;             // Total proposals counter
    uint256 public votingPeriod;              // Voting period duration in blocks
    uint256 public quorumPercentage;          // Minimum % token vote for quorum

    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 deadline;                     // Block number voting ends
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
        mapping(address => bool) voters;
    }

    mapping(uint256 => Proposal) private proposals;

    event ProposalCreated(uint256 indexed id, address indexed proposer, string description, uint256 deadline);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 votes);
    event ProposalExecuted(uint256 indexed proposalId, bool success);

    modifier onlyTokenHolders() {
        require(governanceToken.balanceOf(msg.sender) > 0, "Must hold governance tokens");
        _;
    }

    constructor(IERC20 _governanceToken, uint256 _votingPeriod, uint256 _quorumPercentage) {
        require(_quorumPercentage <= 100, "Quorum must be <= 100");
        governanceToken = _governanceToken;
        votingPeriod = _votingPeriod;
        quorumPercentage = _quorumPercentage;
        proposalCount = 0;
    }

    function createProposal(string calldata _description) external onlyTokenHolders returns (uint256) {
        proposalCount += 1;

        Proposal storage p = proposals[proposalCount];
        p.id = proposalCount;
        p.proposer = msg.sender;
        p.description = _description;
        p.deadline = block.number + votingPeriod;
        p.executed = false;

        emit ProposalCreated(proposalCount, msg.sender, _description, p.deadline);
        return proposalCount;
    }

    function vote(uint256 _proposalId, bool support) external onlyTokenHolders {
        Proposal storage proposal = proposals[_proposalId];
        require(block.number <= proposal.deadline, "Voting period ended");
        require(!proposal.voters[msg.sender], "Already voted");

        uint256 voterBalance = governanceToken.balanceOf(msg.sender);
        require(voterBalance > 0, "No voting power");

        if (support) {
            proposal.votesFor += voterBalance;
        } else {
            proposal.votesAgainst += voterBalance;
        }
        proposal.voters[msg.sender] = true;

        emit Voted(_proposalId, msg.sender, support, voterBalance);
    }

    function executeProposal(uint256 _proposalId) external onlyOwner {
        Proposal storage proposal = proposals[_proposalId];
        require(block.number > proposal.deadline, "Voting still active");
        require(!proposal.executed, "Already executed");

        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        uint256 quorumVotes = (governanceToken.totalSupply() * quorumPercentage) / 100;
        require(totalVotes >= quorumVotes, "Quorum not reached");
        require(proposal.votesFor > proposal.votesAgainst, "Proposal not approved");

        // Execute proposal action here as per DAO logic
        // This is a placeholder for real-world implementation

        proposal.executed = true;
        emit ProposalExecuted(_proposalId, true);
    }

    // View functions for proposal details without exposing internal mapping voters
    function getProposal(uint256 _proposalId) external view returns (
        uint256 id,
        address proposer,
        string memory description,
        uint256 deadline,
        uint256 votesFor,
        uint256 votesAgainst,
        bool executed
    ) {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.id,
            proposal.proposer,
            proposal.description,
            proposal.deadline,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.executed
        );
    }

    function hasVoted(uint256 _proposalId, address voter) external view returns (bool) {
        return proposals[_proposalId].voters[voter];
    }
}
