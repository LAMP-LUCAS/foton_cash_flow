import os
import subprocess
import shutil

CONFIG_FILE = os.path.join(os.path.dirname(__file__), '.config')

def load_config():
    config = {
        'CONTAINER_NAME': 'foton_redmine',
        'PLUGINS_PATH': '/caminho/para/redmine/plugins',
        'PLUGIN_DIR': 'redmine_cash_flow_pro',
    }
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
            for line in f:
                if '=' in line and not line.strip().startswith('#'):
                    k, v = line.strip().split('=', 1)
                    config[k.strip()] = v.strip()
    return config

def run(cmd):
    print(f'Executando: {cmd}')
    subprocess.run(cmd, shell=True, check=True)

def remove():
    cfg = load_config()
    print('Removendo migrações do plugin...')
    run(f"docker compose exec {cfg['CONTAINER_NAME']} bundle exec rake redmine:plugins:migrate NAME={cfg['PLUGIN_DIR']} VERSION=0 RAILS_ENV=production")
    plugin_path = os.path.join(cfg['PLUGINS_PATH'], cfg['PLUGIN_DIR'])
    if os.path.exists(plugin_path):
        print('Removendo diretório do plugin...')
        shutil.rmtree(plugin_path)
    print('Reiniciando o Redmine...')
    run(f"docker compose restart {cfg['CONTAINER_NAME']}")
    print('Remoção concluída!')

if __name__ == '__main__':
    remove()
