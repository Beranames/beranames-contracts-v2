# generate_signature.rb
require 'eth'

# Define the private key (Replace with your actual private key)
private_key = 'ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'

# Initialize the key using Eth::Key
key = Eth::Key.new priv: private_key

# Define the registration parameters
owner = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266' # Alice's address
referrer = '0x0000000000000000000000000000000000000000'  # Example referrer
duration = 365 * 24 * 60 * 60                            # 365 days in seconds
name = 'whitelisted'                                     # Name to register

# ABI encode the payload as per Solidity's abi.encode
abi_encoded = Eth::Abi.encode(%w[
                                address
                                address
                                uint256
                                string
                              ], [owner, referrer, duration, name])

# Calculate the keccak256 hash of the abi_encoded payload
payload_hash = Eth::Util.keccak256(abi_encoded)

signature = key.personal_sign(payload_hash)
r = signature[0..63]
s = signature[64..127]
v = signature[128..129].hex

v += 27 if v < 27

final_signature = "#{r}#{s}#{format('%02x', v)}"
puts 'Signature:'
puts final_signature
