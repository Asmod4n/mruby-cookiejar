class Cookiemonster
  def initialize(db_path)
    @env = MDB::Env.new(maxdbs: 2, mapsize: 2**32)
    @env.open(db_path, MDB::NOSUBDIR)
    @pwdb = @env.database(MDB::CREATE, "passwords")
    @datadb = @env.database(MDB::CREATE, "data")
    @passwdqc = Passwdqc.new
  end

  def empty?
    @pwdb.empty?
  end

  def useradd(user, password)
    user_hash = Crypto.generichash(user, Crypto::GenericHash::BYTES)
    if @pwdb[user_hash]
      raise UserExistsError, "User #{user} already exists"
    end
    if reason = @passwdqc.check(password)
      raise PasswordError, reason
    end

    salt = Crypto::PwHash.salt
    nonce = Crypto::AEAD::Chacha20Poly1305.nonce
    key = Crypto.pwhash(Crypto::AEAD::Chacha20Poly1305::KEYBYTES, password, salt, Crypto::PwHash::OPSLIMIT_MODERATE,
      Crypto::PwHash::MEMLIMIT_MODERATE, Crypto::PwHash::ALG_ARGON2I13)
    seed = RandomBytes.buf(Crypto::Box::SEEDBYTES)
    ciphertext = Crypto::AEAD::Chacha20Poly1305.encrypt(seed, nonce, key, user_hash)
    @pwdb[user_hash] = {salt: salt,
      nonce: nonce,
      ciphertext: ciphertext,
      opslimit: Crypto::PwHash::OPSLIMIT_MODERATE,
      memlimit: Crypto::PwHash::MEMLIMIT_MODERATE}.to_msgpack
    keypair = Crypto::Box.keypair(seed)
    keypair[:secret_key].noaccess
    Cryptor.new(@datadb, keypair)
  ensure
    Sodium.memzero(password) if password
    key.free if key
    Sodium.memzero(seed) if seed
  end

  def login(user, password)
    user_hash = Crypto.generichash(user, Crypto::GenericHash::BYTES)
    unless login = @pwdb[user_hash]
      raise UserNotExistsError, "User #{user} doesn't exist"
    end
    login = MessagePack.unpack(login)
    key = Crypto.pwhash(Crypto::AEAD::Chacha20Poly1305::KEYBYTES, password, login[:salt], login[:opslimit],
      login[:memlimit], Crypto::PwHash::ALG_ARGON2I13)
    seed = Crypto::AEAD::Chacha20Poly1305.decrypt(login[:ciphertext],
    login[:nonce], key, user_hash)
    keypair = Crypto::Box.keypair(seed)
    keypair[:secret_key].noaccess
    Cryptor.new(@datadb, keypair)
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
    user_hash = Crypto.generichash(user, Crypto::GenericHash::BYTES)
    unless login = @pwdb[user_hash]
      raise UserNotExistsError, "User #{user} doesn't exist"
    end

    if reason = @passwdqc.check(newpassword, oldpassword)
      raise PasswordError, reason
    end
  end
end
