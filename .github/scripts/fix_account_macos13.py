from pathlib import Path

path = Path('Halo/Views/WorkspaceSettingsView.swift')
s = path.read_text()
old = '''                TextField("Email", text: $email)\n                    .textContentType(.emailAddress)\n                SecureField("Password", text: $password)\n                    .textContentType(creatingAccount ? .newPassword : .password)\n'''
new = '''                TextField("Email", text: $email)\n                SecureField("Password", text: $password)\n'''
if old not in s:
    raise SystemExit('Account fields block not found')
s = s.replace(old, new, 1)
path.write_text(s)
print('Removed macOS 14-only textContentType values from account fields')
