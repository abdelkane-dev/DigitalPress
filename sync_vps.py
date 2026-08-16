"""Utilitaire de synchronisation VPS (upload + restart services).

⚠️  SÉCURITÉ : le mot de passe SSH n'est JAMAIS stocké dans ce fichier.
Il est lu depuis la variable d'environnement DP_VPS_PASSWORD, ou demandé
interactivement au lancement (getpass, non affiché à l'écran).
"""
import getpass
import os
import paramiko

VPS_IP = os.environ.get("DP_VPS_IP", "192.162.71.56")
VPS_PORT = 22
VPS_USER = os.environ.get("DP_VPS_USER", "root")


def upload_and_restart():
    password = os.environ.get("DP_VPS_PASSWORD") or getpass.getpass(
        f"Mot de passe SSH {VPS_USER}@{VPS_IP} : "
    )

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    print(f"Connexion SSH a {VPS_IP}...")
    ssh.connect(VPS_IP, port=VPS_PORT, username=VPS_USER, password=password, timeout=15)
    print("Connecte !")

    sftp = ssh.open_sftp()
    local_file = "backend/apps/publications/views.py"
    remote_file = "/opt/digitalpress/backend/apps/publications/views.py"
    print(f"Transfert SFTP de {local_file} -> {remote_file}...")
    sftp.put(local_file, remote_file)
    sftp.close()
    print("Fichier transfere avec succes !")

    commands = [
        "systemctl restart digitalpress",
        "systemctl restart digitalpress-daphne",
        "systemctl status digitalpress --no-pager -n 5"
    ]
    for cmd in commands:
        print(f"Execution: {cmd}")
        stdin, stdout, stderr = ssh.exec_command(cmd)
        out = stdout.read().decode('utf-8', errors='ignore')
        err = stderr.read().decode('utf-8', errors='ignore')
        if out:
            print(f"[STDOUT]\n{out}")
        if err:
            print(f"[STDERR]\n{err}")

    ssh.close()
    print("Termine avec succes !")


if __name__ == "__main__":
    upload_and_restart()
