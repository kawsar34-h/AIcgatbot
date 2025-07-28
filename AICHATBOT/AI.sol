// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract AIChatbotDApp {
    address public owner;
    uint256 public totalInteractions;
    uint256 public nextConversationId;
    
    struct Conversation {
        address user;
        string[] messages;
        string[] responses;
        uint256 timestamp;
        uint256 contextScore;
        bool isActive;
    }
    
    struct LearningData {
        string pattern;
        string response;
        uint256 rating;
        uint256 frequency;
    }
    
    mapping(uint256 => Conversation) public conversations;
    mapping(address => uint256[]) public userConversations;
    mapping(string => LearningData) public knowledgeBase;
    mapping(string => uint256) public patternFrequency;
    
    event ConversationCreated(uint256 indexed conversationId, address indexed user);
    event MessageProcessed(uint256 indexed conversationId, string message, string response);
    event LearningUpdated(string pattern, uint256 newRating);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner allowed");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        nextConversationId = 1;
        _initializeKnowledge();
    }
    
    // 1. START CONVERSATION - Creates new chat session
    function startConversation() external returns (uint256 conversationId) {
        conversationId = nextConversationId++;
        
        conversations[conversationId] = Conversation({
            user: msg.sender,
            messages: new string[](0),
            responses: new string[](0),
            timestamp: block.timestamp,
            contextScore: 0,
            isActive: true
        });
        
        userConversations[msg.sender].push(conversationId);
        
        emit ConversationCreated(conversationId, msg.sender);
        return conversationId;
    }
    
    // 2. PROCESS MESSAGE - Core NLP and response generation
    function processMessage(uint256 _conversationId, string memory _message) 
        external 
        returns (string memory response) 
    {
        require(conversations[_conversationId].user == msg.sender, "Not your conversation");
        require(conversations[_conversationId].isActive, "Conversation ended");
        
        // Natural Language Processing
        string memory intent = _analyzeIntent(_message);
        string[] memory keywords = _extractKeywords(_message);
        
        // Context Awareness
        uint256 contextScore = _calculateContext(_conversationId, _message);
        conversations[_conversationId].contextScore = contextScore;
        
        // Generate Response
        response = _generateResponse(intent, keywords, contextScore);
        
        // Store interaction
        conversations[_conversationId].messages.push(_message);
        conversations[_conversationId].responses.push(response);
        totalInteractions++;
        
        emit MessageProcessed(_conversationId, _message, response);
        return response;
    }
    
    // 3. RATE RESPONSE - Learning mechanism
    function rateResponse(uint256 _conversationId, uint256 _responseIndex, uint256 _rating) 
        external 
    {
        require(conversations[_conversationId].user == msg.sender, "Not your conversation");
        require(_rating >= 1 && _rating <= 5, "Rating must be 1-5");
        require(_responseIndex < conversations[_conversationId].responses.length, "Invalid response index");
        
        string memory response = conversations[_conversationId].responses[_responseIndex];
        string memory message = conversations[_conversationId].messages[_responseIndex];
        
        // Learning from interactions
        _updateKnowledge(message, response, _rating);
        
        emit LearningUpdated(message, _rating);
    }
    
    // 4. ADD KNOWLEDGE - Expand AI knowledge base
    function addKnowledge(string memory _pattern, string memory _response) 
        external 
        onlyOwner 
    {
        knowledgeBase[_pattern] = LearningData({
            pattern: _pattern,
            response: _response,
            rating: 3, // Default neutral rating
            frequency: 0
        });
    }
    
    // 5. GET CONVERSATION - Retrieve chat history
    function getConversation(uint256 _conversationId) 
        external 
        view 
        returns (
            string[] memory messages,
            string[] memory responses,
            uint256 contextScore,
            bool isActive
        ) 
    {
        require(
            conversations[_conversationId].user == msg.sender || msg.sender == owner,
            "Access denied"
        );
        
        Conversation memory conv = conversations[_conversationId];
        return (conv.messages, conv.responses, conv.contextScore, conv.isActive);
    }
    
    // 6. END CONVERSATION - Close chat session
    function endConversation(uint256 _conversationId) external {
        require(conversations[_conversationId].user == msg.sender, "Not your conversation");
        conversations[_conversationId].isActive = false;
    }
    
    // Internal Functions
    function _analyzeIntent(string memory _message) internal pure returns (string memory) {
        bytes memory messageBytes = bytes(_message);
        
        if (_contains(_message, "help")) return "support";
        if (_contains(_message, "price") || _contains(_message, "cost")) return "pricing";
        if (_contains(_message, "buy") || _contains(_message, "purchase")) return "transaction";
        if (messageBytes[messageBytes.length - 1] == "?") return "question";
        
        return "general";
    }
    
    function _extractKeywords(string memory _message) internal pure returns (string[] memory) {
        string[] memory keywords = new string[](3);
        
        if (_contains(_message, "token")) keywords[0] = "token";
        if (_contains(_message, "blockchain")) keywords[1] = "blockchain";
        if (_contains(_message, "smart contract")) keywords[2] = "contract";
        
        return keywords;
    }
    
    function _calculateContext(uint256 _conversationId, string memory _message) 
        internal 
        view 
        returns (uint256) 
    {
        Conversation memory conv = conversations[_conversationId];
        uint256 baseScore = 50;
        
        // Increase context score based on conversation length
        if (conv.messages.length > 0) {
            baseScore += 20;
        }
        if (conv.messages.length > 3) {
            baseScore += 15;
        }
        
        return baseScore > 100 ? 100 : baseScore;
    }
    
    function _generateResponse(
        string memory _intent,
        string[] memory _keywords,
        uint256 _contextScore
    ) internal view returns (string memory) {
        // Check knowledge base first
        for (uint i = 0; i < _keywords.length; i++) {
            if (bytes(knowledgeBase[_keywords[i]].response).length > 0) {
                return knowledgeBase[_keywords[i]].response;
            }
        }
        
        // Intent-based responses
        if (_compareStrings(_intent, "support")) {
            return "I'm here to help! What specific assistance do you need?";
        } else if (_compareStrings(_intent, "pricing")) {
            return "For current pricing information, please check our latest rates and market data.";
        } else if (_compareStrings(_intent, "transaction")) {
            return "To proceed with a transaction, ensure you have sufficient balance and verify all details.";
        } else if (_compareStrings(_intent, "question")) {
            return "That's a great question! Could you provide more specific details?";
        }
        
        // Context-aware default response
        if (_contextScore > 70) {
            return "Based on our conversation, I understand your needs better now. How else can I assist?";
        }
        
        return "Hello! I'm your AI assistant. How can I help you today?";
    }
    
    function _updateKnowledge(
        string memory _message,
        string memory _response,
        uint256 _rating
    ) internal {
        string memory pattern = _extractPattern(_message);
        
        if (_rating >= 4) {
            // Good rating - strengthen this pattern
            LearningData storage data = knowledgeBase[pattern];
            if (bytes(data.pattern).length == 0) {
                // New pattern
                knowledgeBase[pattern] = LearningData({
                    pattern: pattern,
                    response: _response,
                    rating: _rating,
                    frequency: 1
                });
            } else {
                // Update existing pattern
                data.rating = (data.rating + _rating) / 2;
                data.frequency++;
            }
        }
    }
    
    function _extractPattern(string memory _text) internal pure returns (string memory) {
        // Simplified pattern extraction - return first significant word
        if (_contains(_text, "help")) return "help";
        if (_contains(_text, "price")) return "price";
        if (_contains(_text, "token")) return "token";
        return "general";
    }
    
    function _initializeKnowledge() internal {
        knowledgeBase["hello"] = LearningData("hello", "Hello! Welcome to our AI chatbot. How can I assist you?", 4, 1);
        knowledgeBase["help"] = LearningData("help", "I'm here to help! Ask me about tokens, prices, or general information.", 4, 1);
        knowledgeBase["token"] = LearningData("token", "Our platform supports various tokens. What specific information do you need?", 4, 1);
    }
    
    // Utility functions
    function _contains(string memory _str, string memory _substr) internal pure returns (bool) {
        bytes memory strBytes = bytes(_str);
        bytes memory substrBytes = bytes(_substr);
        
        if (substrBytes.length > strBytes.length) return false;
        
        for (uint i = 0; i <= strBytes.length - substrBytes.length; i++) {
            bool found = true;
            for (uint j = 0; j < substrBytes.length; j++) {
                if (strBytes[i + j] != substrBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }
    
    function _compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
    
    // View functions
    function getTotalInteractions() external view returns (uint256) {
        return totalInteractions;
    }
    
    function getUserConversationCount(address _user) external view returns (uint256) {
        return userConversations[_user].length;
    }
}
