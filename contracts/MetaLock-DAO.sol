// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MetaLockDAO
 * @dev Minimal token-weighted DAO with timelocked execution of approved proposals
 * @notice Token holders vote; approved proposals are queued and executed after a delay
 */
interface IERC20VotesLike {
    function balanceOf(address account) external view returns (uint256);
}

contract MetaLockDAO {
    IERC20VotesLike public governanceToken;
    address public owner;

    uint256 public votingPeriod;    // seconds
    uint256 public timelockDelay;   // seconds
    uint256 public quorum;          // minimum total votes for validity

    struct Proposal {
        uint256 id;
        address proposer;
        string  description;
        address target;
        uint256 value;
        bytes   data;
        uint256 createdAt;
        uint256 votingEnds;
        uint256 eta;           // execution time (after timelock)
        uint256 forVotes;
        uint256 againstVotes;
        bool    executed;
        bool    canceled;
    }

    uint256 public proposalCount;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(
        uint256 indexed id,
        address indexed proposer,
        address indexed target,
        uint256 value,
        string description,
        uint256 votingEnds
    );

    event VoteCast(
        uint256 indexed id,
        address indexed voter,
        bool support,
        uint256 weight
    );

    event Queued(uint256 indexed id, uint256 eta);
    event Executed(uint256 indexed id);
    event Canceled(uint256 indexed id);

    event ParamsUpdated(uint256 votingPeriod, uint256 timelockDelay, uint256 quorum);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier proposalExists(uint256 id) {
        require(proposals[id].proposer != address(0), "Proposal not found");
        _;
    }

    constructor(
        address _token,
        uint256 _votingPeriod,
        uint256 _timelockDelay,
        uint256 _quorum
    ) {
        require(_token != address(0), "Zero token");
        require(_votingPeriod > 0 && _timelockDelay > 0, "Invalid params");
        governanceToken = IERC20VotesLike(_token);
        owner = msg.sender;
        votingPeriod = _votingPeriod;
        timelockDelay = _timelockDelay;
        quorum = _quorum;
    }

    /**
     * @dev Create a proposal that will call `target.call{value}(data)` if approved & executed
     */
    function propose(
        address target,
        uint256 value,
        bytes calldata data,
        string calldata description
    ) external returns (uint256 id) {
        require(target != address(0), "Zero target");
        require(governanceToken.balanceOf(msg.sender) > 0, "No voting power");

        id = proposalCount++;
        uint256 ends = block.timestamp + votingPeriod;

        proposals[id] = Proposal({
            id: id,
            proposer: msg.sender,
            description: description,
            target: target,
            value: value,
            data: data,
            createdAt: block.timestamp,
            votingEnds: ends,
            eta: 0,
            forVotes: 0,
            againstVotes: 0,
            executed: false,
            canceled: false
        });

        emit ProposalCreated(id, msg.sender, target, value, description, ends);
    }

    /**
     * @dev Vote for/against a proposal
     */
    function vote(uint256 id, bool support)
        external
        proposalExists(id)
    {
        Proposal storage p = proposals[id];
        require(block.timestamp < p.votingEnds, "Voting ended");
        require(!p.canceled, "Canceled");
        require(!hasVoted[id][msg.sender], "Already voted");

        uint256 weight = governanceToken.balanceOf(msg.sender);
        require(weight > 0, "No voting power");

        hasVoted[id][msg.sender] = true;

        if (support) {
            p.forVotes += weight;
        } else {
            p.againstVotes += weight;
        }

        emit VoteCast(id, msg.sender, support, weight);
    }

    /**
     * @dev Queue an approved proposal into timelock
     */
    function queue(uint256 id)
        external
        proposalExists(id)
    {
        Proposal storage p = proposals[id];

        require(block.timestamp >= p.votingEnds, "Voting not ended");
        require(!p.canceled, "Canceled");
        require(!p.executed, "Executed");
        require(p.eta == 0, "Already queued");

        uint256 totalVotes = p.forVotes + p.againstVotes;
        require(totalVotes >= quorum, "No quorum");
        require(p.forVotes > p.againstVotes, "Not approved");

        uint256 eta = block.timestamp + timelockDelay;
        p.eta = eta;

        emit Queued(id, eta);
    }

    /**
     * @dev Execute a queued proposal after timelock delay
     */
    function execute(uint256 id)
        external
        payable
        proposalExists(id)
    {
        Proposal storage p = proposals[id];

        require(!p.canceled, "Canceled");
        require(!p.executed, "Executed");
        require(p.eta != 0, "Not queued");
        require(block.timestamp >= p.eta, "Timelocked");

        p.executed = true;

        (bool ok, ) = p.target.call{value: p.value}(p.data);
        require(ok, "Call failed");

        emit Executed(id);
    }

    /**
     * @dev Cancel a proposal (by proposer or owner) before execution
     */
    function cancel(uint256 id)
        external
        proposalExists(id)
    {
        Proposal storage p = proposals[id];
        require(!p.executed, "Executed");
        require(!p.canceled, "Already canceled");
        require(msg.sender == p.proposer || msg.sender == owner, "Not authorized");

        p.canceled = true;
        emit Canceled(id);
    }

    /**
     * @dev Update DAO parameters
     */
    function updateParams(
        uint256 _votingPeriod,
        uint256 _timelockDelay,
        uint256 _quorum
    ) external onlyOwner {
        require(_votingPeriod > 0 && _timelockDelay > 0, "Invalid params");
        votingPeriod = _votingPeriod;
        timelockDelay = _timelockDelay;
        quorum = _quorum;
        emit ParamsUpdated(_votingPeriod, _timelockDelay, _quorum);
    }

    /**
     * @dev Transfer ownership of admin functions
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }

    /**
     * @dev Helper to get basic proposal data
     */
    function getProposal(uint256 id)
        external
        view
        proposalExists(id)
        returns (
            address proposer,
            string memory description,
            address target,
            uint256 value,
            uint256 createdAt,
            uint256 votingEnds,
            uint256 eta,
            uint256 forVotes,
            uint256 againstVotes,
            bool executed,
            bool canceled
        )
    {
        Proposal memory p = proposals[id];
        return (
            p.proposer,
            p.description,
            p.target,
            p.value,
            p.createdAt,
            p.votingEnds,
            p.eta,
            p.forVotes,
            p.againstVotes,
            p.executed,
            p.canceled
        );
    }
}
