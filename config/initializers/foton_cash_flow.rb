if Rails.env.test?
  Rails.application.config.after_initialize do
    Setting.plugin_foton_cash_flow ||= {}
  end
else
  Setting.plugin_foton_cash_flow ||= {
    'default_columns' => %w[entry_date transaction_type amount category description],
    'custom_projects' => [],
    'permanent_users' => [],
    'categories' => []
  }
end