defmodule ConfTranslateTest do
  use ExUnit.Case

  test "can generate default conf from schema" do
    path   = Path.join(["test", "schemas", "test.schema.exs"])
    schema = path |> Conform.Schema.load
    conf   = schema |> Conform.Translate.to_conf
    assert conf == """
    # The location of the error log. Should be a full path, i.e. /var/log/error.log.
    log.error.file = "/var/log/error.log"

    # The location of the console log. Should be a full path, i.e. /var/log/console.log.
    log.console.file = "/var/log/console.log"

    # This setting determines whether to use syslog or not. Valid values are :on and :off.
    # Allowed values: on, off
    log.syslog = on

    # Restricts the error logging performed by the specified 
    # `sasl_error_logger` to error reports, progress reports, or 
    # both. Default is all. Just testing "nested strings".
    # Allowed values: error, progress, all
    sasl.log.level = all

    # The format to use for Logger.
    logger.format = "$time $metadata[$level] $levelpad$message\n"

    # Remote db hosts
    myapp.db.hosts = 127.0.0.1:8001

    # Just some atom.
    myapp.some_val = foo

    # Determine the type of thing.
    # * active: it's going to be active
    # * passive: it's going to be passive
    # * active-debug: it's going to be active, with verbose debugging information
    # Allowed values: active, passive, active-debug
    myapp.another_val = active

    """
  end

  test "can generate config as Elixir terms from .conf and schema" do
    path   = Path.join(["test", "schemas", "test.schema.exs"])
    schema = path |> Conform.Schema.load
    conf   = schema |> Conform.Translate.to_conf
    parsed = Conform.Parse.parse(conf)
    config = Conform.Translate.to_config([], parsed, schema)
    expect = [
      log: [
        console_file: "/var/log/console.log",
        error_file:   "/var/log/error.log",
        syslog: :on
      ],
      logger: [format: "$time $metadata[$level] $levelpad$message\n"],
      myapp: [
        another_val: {:on, [data: %{log: :warn}]},
        db: [hosts: [{"127.0.0.1", "8001"}]],
        some_val: :bar
      ],
      sasl:  [errlog_type: :all]
    ]
    assert Keyword.equal?(expect, config)
  end

  test "can generate config as Elixir terms from existing config, .conf and schema" do
    config = [sasl: [errlog_type: :error], log: [syslog: :off]]
    path   = Path.join(["test", "schemas", "test.schema.exs"])
    schema = path |> Conform.Schema.load
    conf = """
    # Restricts the error logging performed by the specified 
    # `sasl_error_logger` to error reports, progress reports, or 
    # both. Default is all. Just testing "nested strings".
    sasl.log.level = progress

    # Determine the type of thing.
    # * active: it's going to be active
    # * passive: it's going to be passive
    # * active-debug: it's going to be active, with verbose debugging information
    myapp.another_val = active
    """
    parsed = Conform.Parse.parse(conf)
    config = Conform.Translate.to_config(config, parsed, schema)
    expect = [
      log: [
        console_file: "/var/log/console.log",
        error_file:   "/var/log/error.log",
        syslog: :on
      ],
      logger: [format: "$time $metadata[$level] $levelpad$message\n"],
      myapp: [
        another_val: {:on, [data: %{log: :warn}]},
        db: [hosts: [{"127.0.0.1", "8001"}]],
        some_val: :bar
      ],
      sasl:  [errlog_type: :progress]
    ]
    assert Keyword.equal?(expect, config)
  end

  test "can write config to disk as Erlang terms in valid app/sys.config format" do
    path   = Path.join(["test", "schemas", "test.schema.exs"])
    schema = path |> Conform.Schema.load
    conf   = schema |> Conform.Translate.to_conf
    parsed = Conform.Parse.parse(conf)
    config = Conform.Translate.to_config([], parsed, schema)

    config_path = Path.join(System.tmp_dir!, "conform_test.config")
    :ok    = config_path |> Conform.Config.write(config)
    result = config_path |> String.to_char_list |> :file.consult
    config_path |> File.rm!
    assert {:ok, [^config]} = result
  end
end