pragma solidity >=0.7.0 <0.9.0;
/// @title Signing Food Certifications with delegation.
contract Signing {
    // This declares a new complex type which will
    // be used for variables later.
    // It will represent a single signer.
    struct Signer {
        uint weight; // weight is accumulated by delegation
        bool signed;  // if true, that person already signed
        address delegate; // person delegated to
        uint sign;   // index of the signed certificate
    }

    // This is a type for a single certificate.
    struct Certificate {
        bytes32 name;   // short name (up to 32 bytes)
        uint signCount; // number of accumulated signs
    }

    address public chairperson;

    // This declares a state variable that
    // stores a `Signer` struct for each possible address.
    mapping(address => Signer) public signers;

    // A dynamically-sized array of `Certificate` structs.
    Certificate[] public certificates;

    /// Create a new signing instance to choose one of `certificateNames`.
    constructor(bytes32[] memory certificateNames) {
        chairperson = msg.sender;
        signers[chairperson].weight = 1;

        // For each of the provided certificate names,
        // create a new certificate object and add it
        // to the end of the array.
        for (uint i = 0; i < certificateNames.length; i++) {
            // `Certificate({...})` creates a temporary
            // Certificate object and `certificates.push(...)`
            // appends it to the end of `certificates`.
            certificates.push(Certificate({
                name: certificateNames[i],
                signCount: 0
            }));
        }
    }

    // Give `signer` the right to sign on this singing.
    // May only be called by `chairperson`.
    function giveRightToSign(address signer) external {
        // If the first argument of `require` evaluates
        // to `false`, execution terminates and all
        // changes to the state and to Ether balances
        // are reverted.
        // This used to consume all gas in old EVM versions, but
        // not anymore.
        // It is often a good idea to use `require` to check if
        // functions are called correctly.
        // As a second argument, you can also provide an
        // explanation about what went wrong.
        require(
            msg.sender == chairperson,
            "Only chairperson can give right to sign."
        );
        require(
            !signers[signer].signed,
            "The signer already signed."
        );
        require(signers[signer].weight == 0);
        signers[signer].weight = 1;
    }

    /// Delegate your sign to the signer `to`.
    function delegate(address to) external {
        // assigns reference
        Signer storage sender = signers[msg.sender];
        require(sender.weight != 0, "You have no right to sign");
        require(!sender.signed, "You already signed.");

        require(to != msg.sender, "Self-delegation is disallowed.");

        // Forward the delegation as long as
        // `to` also delegated.
        // In general, such loops are very dangerous,
        // because if they run too long, they might
        // need more gas than is available in a block.
        // In this case, the delegation will not be executed.
       
        while (signers[to].delegate != address(0)) {
            to = signers[to].delegate;

            // We found a loop in the delegation, not allowed.
            require(to != msg.sender, "Found loop in delegation.");
        }

        Signer storage delegate_ = signers[to];

        // Signers cannot delegate to accounts that cannot sign.
        require(delegate_.weight >= 1);

        // Since `sender` is a reference, this
        // modifies `signers[msg.sender]`.
        sender.signed = true;
        sender.delegate = to;

        if (delegate_.signed) {
            // If the delegate already signed,
            // directly add to the number of signs
            certificates[delegate_.sign].signCount += sender.weight;
        } else {
            // If the delegate did not sign yet,
            // add to her weight.
            delegate_.weight += sender.weight;
        }
    }

    /// Give your sign (including signs delegated to you)
    /// to certificate `certificates[certificate].name`.
    function sign(uint certificate) external {
        Signer storage sender = signers[msg.sender];
        require(sender.weight != 0, "Has no right to sign");
        require(!sender.signed, "Already signed.");
        sender.signed = true;
        sender.sign = certificate;

        // If `certificate` is out of the range of the array,
        // this will throw automatically and revert all
        // changes.
        certificates[certificate].signCount += sender.weight;
    }

    /// @dev Computes the winning certificate taking all
    /// previous signs into account.
    function MostSignedCertificate() public view
            returns (uint MostSignedCertificate_)
    {
        uint winningSignCount = 0;
        for (uint p = 0; p < certificates.length; p++) {
            if (certificates[p].signCount > winningSignCount) {
                winningSignCount = certificates[p].signCount;
                MostSignedCertificate_ = p;
            }
        }
    }

    // Calls MostSignedCertificate() function to get the index
    // of the winner contained in the certificates array and then
    // returns the name of the most trusted exporter/importer.
    function TrustedImporter() external view
            returns (bytes32 TrustedImporter_)
    {
        TrustedImporter_ = certificates[MostSignedCertificate()].name;
    }
}

