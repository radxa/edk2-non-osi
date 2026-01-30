from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend
import hashlib
import sys
import argparse
from asn1crypto.keys import PublicKeyInfo
import crcmod

def create_hash_bin(file_path):
    with open(file_path, "rb") as key_file:
        private_key = serialization.load_pem_private_key(
            key_file.read(),
            password=None,
            backend=default_backend()
        )

    public_key = private_key.public_key()
    public_key_der = public_key.public_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PublicFormat.SubjectPublicKeyInfo
    )
    public_key_info = PublicKeyInfo.load(public_key_der)
    rsa_public_key = public_key_info['public_key'].native
    modulus = rsa_public_key['modulus']
    exponent = rsa_public_key['public_exponent']
    raw_public_key = modulus.to_bytes((modulus.bit_length() + 7) // 8, byteorder='big') + \
                     exponent.to_bytes((exponent.bit_length() + 7) // 8, byteorder='big')

    sha256_hash = hashlib.sha256(raw_public_key).digest()
    crc16_func = crcmod.mkCrcFun(0x11021, initCrc=0xFFFF, rev=False, xorOut=0x0000)
    crc_value = crc16_func(sha256_hash)
    print("CRC-16/CCITT-FALSE: 0x{:04X}".format(crc_value))
    crc_bytes = crc_value.to_bytes(2, byteorder='little')

    print("Public Key SHA-256 Hash:", sha256_hash.hex())
    print("CRC16 (Hex):", crc_bytes.hex())

    combined_data = sha256_hash + crc_bytes + b'\x00' + b'\x00';
    with open("hash.bin", "wb") as binary_file:
        binary_file.write(combined_data)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate SHA-256 hash of a public key with crc16 from a private key PEM file.")
    parser.add_argument("input_file", help="Path to the private key PEM file.")
    args = parser.parse_args()

    create_hash_bin(args.input_file)
