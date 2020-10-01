import crypt
import hmac

from radicale.auth import BaseAuth

class Auth(BaseAuth):

    def __init__(self, configuration):
        super().__init__(configuration)
        self._filename = configuration.get("auth", "htpasswd_filename")


    def _crypt(self, hash_value, password):
        """Check if ``hash_value`` and ``password`` match, crypt method."""
        hash_value = hash_value.strip()
        return hmac.compare_digest(crypt.crypt(password, hash_value),
                                   hash_value)

    def login(self, login, password):
        """Validate credentials.
        Iterate through htpasswd credential file until login matches, extract
        hash (encrypted password) and check hash against password,
        using the method specified in the Radicale config.
        The content of the file is not cached because reading is generally a
        very cheap operation, and it's useful to get live updates of the
        htpasswd file.
        """
        try:
            with open(self._filename) as f:
                for line in f:
                    line = line.rstrip("\n")
                    if line.lstrip() and not line.lstrip().startswith("#"):
                        try:
                            hash_login, hash_value = line.split(":", maxsplit=1)
                            # Always compare both login and password to avoid
                            # timing attacks, see #591.
                            login_ok = hmac.compare_digest(hash_login, login)
                            password_ok = self._crypt(hash_value, password)
                            if login_ok and password_ok:
                                return login
                        except ValueError as e:
                            raise RuntimeError("Invalid htpasswd file %r: %s" %
                                               (self._filename, e)) from e
        except OSError as e:
            raise RuntimeError("Failed to load htpasswd file %r: %s" %
                               (self._filename, e)) from e
        return ""
