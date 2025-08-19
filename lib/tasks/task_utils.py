# task_utils.py
import os
import subprocess
from subprocess import CalledProcessError

CONFIG_FILE = os.path.join(os.path.dirname(__file__), '.config')

def load_config():
    """Carrega a configuração a partir do arquivo .config."""
    config = {'CONTAINER_NAME': 'redmine', 'PROJECT_ROOT_PATH': '/'}
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
            for line in f:
                if '=' in line and not line.strip().startswith('#'):
                    key, value = line.strip().split('=', 1)
                    config[key.strip()] = value.strip()
    return config

def run_command(cmd, working_dir):
    """Executa um comando no diretório de trabalho especificado, parando em caso de erro."""
    print(f"Executando em '{working_dir}': {cmd}")
    try:
        # Usamos capture_output=True e text=True para obter stdout/stderr como strings
        subprocess.run(
            cmd,
            shell=True,
            check=True,
            cwd=working_dir,
            capture_output=True,
            text=True,
            encoding='utf-8' # Garante a decodificação correta
        )
    except CalledProcessError as e:
        # Se o comando falhar, imprime os detalhes para facilitar a depuração
        print(f"\n--- ERRO AO EXECUTAR COMANDO ---")
        print(f"Comando: {e.cmd}")
        print(f"Código de Saída: {e.returncode}")
        if e.stdout:
            print(f"--- Saída Padrão (stdout) ---\n{e.stdout.strip()}")
        if e.stderr:
            print(f"--- Saída de Erro (stderr) ---\n{e.stderr.strip()}")
        print("----------------------------------\n")
        # Re-lança a exceção para que o script chamador possa tratá-la (ou parar)
        raise

def publish_plugin_assets(cfg, project_root, step_message):
    """
    Tenta executar a tarefa 'redmine:plugins:assets'.
    Em versões mais recentes do Redmine, esta tarefa não existe mais.
    O erro é capturado e um aviso é exibido, permitindo que o script continue.
    """
    print(step_message)
    try:
        run_command(
            f"docker compose exec {cfg['CONTAINER_NAME']} bundle exec rake redmine:plugins:assets RAILS_ENV=production",
            working_dir=project_root
        )
    except CalledProcessError:
        print("    -> Aviso: A tarefa 'redmine:plugins:assets' falhou. Isso é normal e esperado em versões mais recentes do Redmine. Continuando...")