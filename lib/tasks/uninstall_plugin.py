# uninstall_plugin.py
import os
import sys
import shutil
from task_utils import load_config, run_command, CalledProcessError

def uninstall(plugin_name):
    """Desinstala um plugin do Redmine, revertendo migrações e removendo seus arquivos."""
    cfg = load_config()
    project_root = cfg['PROJECT_ROOT_PATH']
    plugin_path = os.path.join(project_root, 'redmine', 'plugins', plugin_name)

    print(f"--- Desinstalando plugin: {plugin_name} ---")

    print("1/4: Revertendo migrações do plugin (VERSION=0)...")
    run_command(f"docker compose exec {cfg['CONTAINER_NAME']} bundle exec rake redmine:plugins:migrate NAME={plugin_name} VERSION=0 RAILS_ENV=production",
        working_dir=project_root)

    if os.path.isdir(plugin_path):
        print(f"2/4: Removendo diretório do plugin em '{plugin_path}'...")
        shutil.rmtree(plugin_path)
    else:
        print(f"2/4: Diretório do plugin '{plugin_path}' não encontrado. Pulando.")

    print("3/4: Publicando assets (para limpar referências em retrocompatibilidade)...)...")
    try:
        run_command(f"docker compose exec {cfg['CONTAINER_NAME']} bundle exec rake redmine:plugins:assets RAILS_ENV=production",
            working_dir=project_root)
    except CalledProcessError:
        # Se o comando falhar, captura o erro, imprime um aviso e continua
        print("    -> Aviso: A tarefa 'redmine:plugins:assets' falhou. Isso é normal e esperado em versões mais recentes do Redmine. Continuando...")
    

    print("4/4: Reiniciando o Redmine...")
    run_command(f"docker compose restart {cfg['CONTAINER_NAME']}",
        working_dir=project_root)

    print(f"Desinstalação do plugin '{plugin_name}' concluída! ✅")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(f"Uso: python3 {os.path.basename(__file__)} <nome_do_plugin>")
        sys.exit(1)
    plugin_to_uninstall = sys.argv[1]
    uninstall(plugin_to_uninstall)