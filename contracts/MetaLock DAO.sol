Function 1: Add new DAO member
    function addMember(address _member) public onlyOwner {
        members[_member] = true;
    }

    Function 3: Vote on a proposal
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
// 
update
// 
