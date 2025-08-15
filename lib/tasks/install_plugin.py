# install_plugin.py
import sys
from task_utils import load_config, run_command


def install(plugin_name):
    """Instala um plugin no Redmine, executando migrações e publicando assets."""
    cfg = load_config()
    project_root = cfg['PROJECT_ROOT_PATH']

    print(f"--- Instalando plugin: {plugin_name} ---")

    print("1/3: Executando migrações do plugin...")
    run_command(f"docker compose exec {cfg['CONTAINER_NAME']} bundle exec rake redmine:plugins:migrate NAME={plugin_name} RAILS_ENV=production",
        working_dir=project_root)

    print("2/3: Publicando assets do plugin...")
    run_command(f"docker compose exec {cfg['CONTAINER_NAME']} bundle exec rake redmine:plugins:assets RAILS_ENV=production",
        working_dir=project_root)

    print("3/3: Reiniciando o Redmine...")
    run_command(f"docker compose restart {cfg['CONTAINER_NAME']}",
        working_dir=project_root)

    print(f"Instalação do plugin '{plugin_name}' concluída! ✅")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(f"Uso: python3 {os.path.basename(__file__)} <nome_do_plugin>")
        sys.exit(1)
    plugin_to_install = sys.argv[1]
    install(plugin_to_install)