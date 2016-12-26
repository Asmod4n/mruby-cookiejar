class Cookiejar
  class Cryptor
    def initialize(datadb, keypair)
      unless Crypto::Box::PRIMITIVE == keypair[:primitive]
        raise ArgumentError, "keypair can only be a Crypto::Box.keypair"
      end
      @datadb = datadb
      @keypair = keypair
    end

    def []=(key, value)
      msgpack_value = value.to_msgpack
      nonce = Crypto::Box.nonce
      @keypair[:secret_key].readonly
      ciphertext = Crypto.box(msgpack_value, nonce, @keypair[:public_key], @keypair[:secret_key])
      hash = Crypto.generichash(key, Crypto::GenericHash::BYTES, @keypair[:secret_key])
      @datadb[hash] = {nonce: nonce, ciphertext: ciphertext}.to_msgpack
      self
    ensure
      Sodium.memzero(key) if key
      Sodium.memzero(value) if value.respond_to?(:bytesize)
      Sodium.memzero(msgpack_value) if msgpack_value
      @keypair[:secret_key].noaccess
    end

    def [](key)
      @keypair[:secret_key].readonly
      hash = Crypto.generichash(key, Crypto::GenericHash::BYTES, @keypair[:secret_key])
      unless ciphertext = @datadb[hash]
        return nil
      end
      ciphertext = MessagePack.unpack(ciphertext)
      value = Crypto::Box.open(ciphertext[:ciphertext], ciphertext[:nonce], @keypair[:public_key], @keypair[:secret_key])
      MessagePack.unpack(value)
    ensure
      Sodium.memzero(key) if key
      @keypair[:secret_key].noaccess
      Sodium.memzero(value) if value
    end

    def del(key)
      @keypair[:secret_key].readonly
      hash = Crypto.generichash(key, Crypto::GenericHash::BYTES, @keypair[:secret_key])
      @datadb.del(hash)
      self
    ensure
      Sodium.memzero(key) if key
      @keypair[:secret_key].noaccess
    end

    def drop
      @datadb.drop(true)
      self
    end
  end
end
