  ---                                                                             
  name: vault                                                                     
  description: Encrypt or decrypt the Ansible vault                               
  ---                                                                             
                                                                                  
  Check and manage ai-ansible/vars/vault.yml encryption status.                   
  - If user says "encrypt": run ansible-vault encrypt                             
  - If user says "decrypt": run ansible-vault decrypt                             
  - If user says "status": check if file is encrypted                             
  Always use --vault-password-file=.vault_pass
