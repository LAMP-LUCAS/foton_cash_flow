# Makefile para simplificar as tarefas de gerenciamento do plugin foton_cash_flow

# Define o nome do plugin como uma variável.
# Pode ser sobrescrito na linha de comando, ex: make install plugin=outro_plugin
PLUGIN ?= foton_cash_flow

# Define o caminho para os scripts de tarefas do plugin
TASKS_PATH = plugins/$(PLUGIN)/lib/tasks

.PHONY: install update uninstall

install:
	@echo ">> Instalando o plugin $(PLUGIN)..."
	@python3 $(TASKS_PATH)/install_plugin.py $(PLUGIN)

update:
	@echo ">> Atualizando o plugin $(PLUGIN)..."
	@python3 $(TASKS_PATH)/update_plugin.py $(PLUGIN)

uninstall:
	@echo ">> Desinstalando o plugin $(PLUGIN)..."
	@python3 $(TASKS_PATH)/uninstall_plugin.py $(PLUGIN)