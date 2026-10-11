<p align="center">
  <img src="assets/images/logo.png" alt="CredVault logo" width="128">
</p>

# CredVault 🔐

**A zero-knowledge password vault for Android, iOS, the web and Windows.** Everything you save is encrypted on your device with a key made from your master password *before* it is sent to Firebase, so the server only ever holds scrambled data. CredVault also generates strong passwords, grades the health of your vault, and checks passwords against known data breaches without revealing them.

<p align="center">
  <img src="docs/screenshots/04-vault.png" alt="Vault" width="270">
  &nbsp;
  <img src="docs/screenshots/10-security.png" alt="Security score" width="270">
  &nbsp;
  <img src="docs/screenshots/09-generator.png" alt="Password generator" width="270">
</p>

## 🎨 Logo and app icon

<p align="center">
  <img src="assets/images/logo.png" alt="CredVault logo (512 x 512)" width="200">
</p>

A gold shield with a keyhole on midnight navy: your credentials, locked away safely. The same navy-and-gold palette runs through the whole app.


## ✨ Features

**Protecting your data**
- 🔒 **Zero-knowledge encryption** - AES-256-GCM, with the key derived from your master password (PBKDF2-HMAC-SHA256, 200,000 rounds, random salt). The master password is never stored or sent anywhere.
- 🔑 **Master-password lock** - unlock on every launch. The vault locks itself after the app has been in the background (immediately, 1, 5 or 15 minutes) and wipes decrypted data from memory.
- 📋 **Self-clearing clipboard** - copied passwords are wiped after 15 s, 30 s or 1 min (only if the clipboard still holds them).
- 👁️ **Passwords stay hidden** - revealing one hides it again after 20 seconds.
- 🚫 **No screenshots in release builds** on Android (and a blank recent-apps preview).
- 🗑️ **Real account deletion** - asks for your password, then removes your data and account.

**Using it**
- ⚡ **Password generator** - 8 to 64 characters, choose character types, skip look-alikes (`O`, `0`, `l`, `1`), with a live strength meter.
- 📊 **Security score** - finds weak, reused and old (180+ day) passwords, and gives the whole vault a 0 - 100 score.
- 🛰️ **Breach scan** - checks passwords against [Have I Been Pwned](https://haveibeenpwned.com/Passwords) using k-anonymity: only the first 5 characters of a SHA-1 hash are sent.
- 🗂️ **Organise** - 30+ services with brand icons, categories, favourites, notes, a custom name for anything else, search, and sorting (recent, A-Z, oldest, weakest).
- ↩️ **Undo** deleting a login.
- 🌐 **Open a saved website** straight from the login.
- 🔄 **Live sync** across devices, with offline support on phones.
- 🧱 **Master password change** that re-encrypts the whole vault.

## 📸 Screenshots

<table>
  <tr>
    <td align="center"><b>Sign in</b></td>
    <td align="center"><b>Create a vault</b></td>
    <td align="center"><b>Locked</b></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/01-sign-in.png" alt="Sign in" width="250"></td>
    <td><img src="docs/screenshots/02-create-vault.png" alt="Create a vault" width="250"></td>
    <td><img src="docs/screenshots/03-locked.png" alt="Lock screen" width="250"></td>
  </tr>
  <tr>
    <td align="center"><b>Your vault</b></td>
    <td align="center"><b>Login details</b></td>
    <td align="center"><b>Password revealed</b></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/04-vault.png" alt="Vault" width="250"></td>
    <td><img src="docs/screenshots/05-details.png" alt="Login details" width="250"></td>
    <td><img src="docs/screenshots/06-details-revealed.png" alt="Details with the password revealed" width="250"></td>
  </tr>
  <tr>
    <td align="center"><b>Add a login</b></td>
    <td align="center"><b>Choose a service</b></td>
    <td align="center"><b>Generator</b></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/07-add-login.png" alt="Add a login" width="250"></td>
    <td><img src="docs/screenshots/08-pick-service.png" alt="Service picker" width="250"></td>
    <td><img src="docs/screenshots/09-generator.png" alt="Generator" width="250"></td>
  </tr>
  <tr>
    <td align="center"><b>Security score</b></td>
    <td align="center"><b>Breach scan results</b></td>
    <td align="center"><b>Profile and settings</b></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/10-security.png" alt="Security score" width="250"></td>
    <td><img src="docs/screenshots/11-security-scan.png" alt="Breach scan results" width="250"></td>
    <td><img src="docs/screenshots/12-profile.png" alt="Profile and settings" width="250"></td>
  </tr>
</table>

### On the web and Windows

Phones keep the bottom navigation bar and single-column list. On wide windows (840 px and up) the app switches to a side navigation rail and a multi-column vault grid.

<p align="center">
  <img src="docs/screenshots/13-vault-wide.png" alt="Vault on a wide screen" width="460">
  &nbsp;
  <img src="docs/screenshots/14-security-wide.png" alt="Security score on a wide screen" width="460">
</p>


## 🛡️ How your data is protected

```
master password ──PBKDF2-HMAC-SHA256 (200k rounds, random salt)──▶ vault key (256-bit)
                                                                      │
 login (username, password, URL, notes, ...) ──AES-256-GCM, fresh nonce──▶ ciphertext ──▶ Firestore
```

| | What the server stores | Who can read it |
| --- | --- | --- |
| Credentials | One encrypted blob per login (service, username, password, URL, notes, category... all inside it) | Only someone with your master password |
| Vault settings | Random salt, iteration count, an encrypted check value | Not secret: they only let *your device* derive the key |
| Profile | Name, email, created date | You |
| Master password | **Nothing** | Only you |

- **Wrong password = nothing.** The check value is decrypted to verify the master password; a wrong one yields no key and no data.
- **Tampering is detected.** AES-GCM authenticates every record, so a modified record fails to decrypt instead of showing wrong data.
- **No recovery, by design.** If you forget the master password, nobody can decrypt your vault. You can erase the vault and start again (you will be asked for your account password).
- **Key stays in memory only** and is dropped when the vault locks.

**What this does not protect against:** malware on an unlocked device, someone who sees you type your master password, or a weak master password (the app rejects ones that are too easy to guess, but cannot make you choose a good one).

## 💻 Where it runs

| Platform | Supported |
| --- | --- |
| Android | Yes |
| iOS | Yes |
| Web (any modern browser) | Yes |
| Windows | Yes |

Phones use the compact mobile layout. On the web and Windows the app adapts to the wider window.

---

Built with 💥 by DarkWizardCK
