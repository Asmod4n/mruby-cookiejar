class Cookiemonster
  class Cryptor
    def initialize(datadb, keypair)
      @datadb = datadb
      @keypair = keypair
    end

    def []=(key, value)
      nonce = Crypto::Box.nonce
      @keypair[:secret_key].readonly
      ciphertext = Crypto.box(value.to_msgpack, nonce, @keypair[:public_key], @keypair[:secret_key])
      hash = Crypto.generichash(key, Crypto::GenericHash::BYTES, @keypair[:secret_key])
      @datadb[hash] = {nonce: nonce, ciphertext: ciphertext}.to_msgpack
      self
    ensure
      @keypair[:secret_key].noaccess
      Sodium.memzero(key, key.bytesize) if key
      Sodium.memzero(value, value.bytesize) if value
    end

    def [](key)
      @keypair[:secret_key].readonly
      hash = Crypto.generichash(key, Crypto::GenericHash::BYTES, @keypair[:secret_key])
      unless ciphertext = @datadb[hash]
        return nil
      end
      ciphertext = MessagePack.unpack(ciphertext)
      value = Crypto::Box.open(ciphertext[:ciphertext], ciphertext[:nonce], @keypair[:public_key], @keypair[:secret_key])
      MessagePack.unpack(value, true)
    ensure
      @keypair[:secret_key].noaccess
      Sodium.memzero(key, key.bytesize) if key
      Sodium.memzero(value, value.bytesize) if value
    end
  end
end
