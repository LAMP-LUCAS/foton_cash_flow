# update_plugin.py
import os
import sys
from task_utils import load_config, run_command, publish_plugin_assets


def update(plugin_name):
    """Atualiza um plugin existente, puxando as últimas alterações e rodando as migrações."""
    cfg = load_config()
    project_root = cfg['PROJECT_ROOT_PATH']
    plugin_path = os.path.join(project_root, 'redmine', 'plugins', plugin_name)

    print(f"--- Atualizando plugin: {plugin_name} ---")

    print("1/4: Atualizando repositório do plugin via Git...")
    # De acordo com nomenclaturas.md, 'develop' é a branch de integração para novas funcionalidades.
    # Use 'main' se o objetivo for atualizar para a última versão estável.
    run_command('git pull origin develop', working_dir=plugin_path)

    print("2/4: Executando migrações do plugin...")
    run_command(f"docker compose exec {cfg['CONTAINER_NAME']} bundle exec rake redmine:plugins:migrate NAME={plugin_name} RAILS_ENV=production",
        working_dir=project_root)

    publish_plugin_assets(cfg, project_root, "3/4: Publicando assets do plugin (para Retrocompatibilidade)...")

    print("4/4: Reiniciando o Redmine...")
    run_command(f"docker compose restart {cfg['CONTAINER_NAME']}",
        working_dir=project_root)

    print(f"Atualização do plugin '{plugin_name}' concluída! ✅")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(f"Uso: python3 {os.path.basename(__file__)} <nome_do_plugin>")
        sys.exit(1)
    plugin_to_update = sys.argv[1]
    update(plugin_to_update)