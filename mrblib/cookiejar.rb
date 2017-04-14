class Cookiejar
  MessagePack.register_pack_type(1, Symbol) { |symbol| symbol.to_s }
  MessagePack.register_unpack_type(1) { |data| data.to_sym }

  def initialize(db_path)
    @env = MDB::Env.new(maxdbs: 127, mapsize: 2**32)
    @env.open(db_path, MDB::NOSUBDIR)
    @pwdb = @env.database(MDB::CREATE, "passwords")
    @passwdqc = Passwdqc.new
  end

  def empty?
    @pwdb.empty?
  end

  def useradd(user, password)
    user_hash = Crypto.generichash(user, Crypto::GenericHash::BYTES)
    if @pwdb[user_hash]
      raise UserExistsError, "User already exists"
    end
    if reason = @passwdqc.check(password)
      raise PasswordError, reason
    end

    salt = Crypto::PwHash.salt
    nonce = Crypto::AEAD::Chacha20Poly1305.nonce
    key = Crypto.pwhash(Crypto::AEAD::Chacha20Poly1305::KEYBYTES, password, salt, Crypto::PwHash::OPSLIMIT_MODERATE,
      Crypto::PwHash::MEMLIMIT_MODERATE, Crypto::PwHash::ALG_ARGON2I13)
    seed = RandomBytes.buf(Sodium::SecureBuffer.new(Crypto::Box::SEEDBYTES))
    seed.readonly
    ciphertext = Crypto::AEAD::Chacha20Poly1305.encrypt(seed, nonce, key, user_hash)
    @pwdb[user_hash] = {
      primitive: "chacha20poly1305",
      salt: salt,
      nonce: nonce,
      ciphertext: ciphertext,
      opslimit: Crypto::PwHash::OPSLIMIT_MODERATE,
      memlimit: Crypto::PwHash::MEMLIMIT_MODERATE}.to_msgpack
    keypair = Crypto::Box.keypair(seed)
    seed.noaccess
    keypair[:secret_key].noaccess
    Cryptor.new(@env.database(MDB::CREATE, Sodium.bin2hex(user_hash)), keypair)
  ensure
    Sodium.memzero(password) if password
    key.free if key
    seed.free if seed
  end

  def login(user, password)
    user_hash = Crypto.generichash(user, Crypto::GenericHash::BYTES)
    unless login = @pwdb[user_hash]
      raise UserNotExistsError, "User doesn't exist"
    end
    login = MessagePack.unpack(login)
    key = Crypto.pwhash(Crypto::AEAD::Chacha20Poly1305::KEYBYTES, password, login[:salt], login[:opslimit],
      login[:memlimit], Crypto::PwHash::ALG_ARGON2I13)
    seed = Crypto::AEAD::Chacha20Poly1305.decrypt(login[:ciphertext],
    login[:nonce], key, user_hash)
    keypair = Crypto::Box.keypair(seed)
    keypair[:secret_key].noaccess
    Cryptor.new(@env.database(MDB::CREATE, Sodium.bin2hex(user_hash)), keypair)
  ensure
    Sodium.memzero(password) if password
    key.free if key
    Sodium.memzero(seed) if seed
  end

  def backup(path)
    @env.copy2(path, MDB::CP_COMPACT)
    self
  end

  def passwd(user, oldpassword, newpassword)
    if reason = @passwdqc.check(newpassword, oldpassword)
      raise PasswordError, reason
    end
    user_hash = Crypto.generichash(user, Crypto::GenericHash::BYTES)
    unless login = @pwdb[user_hash]
      raise UserNotExistsError, "User doesn't exist"
    end

    login = MessagePack.unpack(login)
    key = Crypto.pwhash(Crypto::AEAD::Chacha20Poly1305::KEYBYTES, oldpassword, login[:salt], login[:opslimit],
      login[:memlimit], Crypto::PwHash::ALG_ARGON2I13)
    seed = Crypto::AEAD::Chacha20Poly1305.decrypt(login[:ciphertext],
    login[:nonce], key, user_hash)
    key.free

    salt = Crypto::PwHash.salt
    nonce = Crypto::AEAD::Chacha20Poly1305.nonce
    key = Crypto.pwhash(Crypto::AEAD::Chacha20Poly1305::KEYBYTES, newpassword, salt, login[:opslimit],
      login[:memlimit], Crypto::PwHash::ALG_ARGON2I13)
    ciphertext = Crypto::AEAD::Chacha20Poly1305.encrypt(seed, nonce, key, user_hash)
    @pwdb[user_hash] = {
      primitive: "chacha20poly1305",
      salt: salt,
      nonce: nonce,
      ciphertext: ciphertext,
      opslimit: login[:opslimit],
      memlimit: login[:memlimit]}.to_msgpack
    keypair = Crypto::Box.keypair(seed)
    keypair[:secret_key].noaccess
    Cryptor.new(@env.database(MDB::CREATE, Sodium.bin2hex(user_hash)), keypair)
  ensure
    Sodium.memzero(oldpassword) if oldpassword
    Sodium.memzero(newpassword) if newpassword
    key.free unless key.nil?
    Sodium.memzero(seed) if seed
  end
end
