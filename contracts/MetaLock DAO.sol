// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MetaLockDAO {
    address public owner;
    uint256 public proposalCount;

    struct Proposal {
        uint256 id;
        string description;
        uint256 votes;
        bool executed;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => bool) public members;

    event ProposalCreated(uint256 id, string description);
    event Voted(uint256 proposalId, address voter);
    event Executed(uint256 proposalId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier onlyMember() {
        require(members[msg.sender], "Not a DAO member");
        _;
    }

    constructor() {
        owner = msg.sender;
        members[msg.sender] = true;
    }

    // Function 1: Add new DAO member
    function addMember(address _member) public onlyOwner {
        members[_member] = true;
    }

    // Function 2: Create new proposal
    function createProposal(string memory _description) public onlyMember {
        proposalCount++;
        proposals[proposalCount] = Proposal(proposalCount, _description, 0, false);
        emit ProposalCreated(proposalCount, _description);
    }

    // Function 3: Vote on a proposal
    function vote(uint256 _proposalId) public onlyMember {
        require(_proposalId <= proposalCount && _proposalId > 0, "Invalid proposal");
        proposals[_proposalId].votes++;
        emit Voted(_proposalId, msg.sender);
    }

    // Optional Function 4: Execute proposal
    function executeProposal(uint256 _proposalId) public onlyOwner {
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.executed, "Already executed");
        proposal.executed = true;
        emit Executed(_proposalId);
    }
}
