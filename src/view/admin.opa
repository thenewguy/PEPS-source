/*
 * PEPS is a modern collaboration server
 * Copyright (C) 2015 MLstate
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published
 * by the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


package com.mlstate.webmail.view

AdminView = {{


  register_callback(callback_opt, res) =
  match res with
  | {failure=e} ->
    Notifications.error(@i18n("Registration Failed"), <>{e}</>)
  | {success=(is_admin,user)} ->
    do Notifications.success(@i18n("Registration Successful"), <>{@i18n("Congratulations.")}</>)
    match callback_opt with
    | {some=cb} -> cb(user)
    | {none} ->
      if is_admin then Content.reset()
      else
        do Dom.set_value(#loginbox_username, Dom.get_value(#register_username))
        do Dom.set_value(#loginbox_password, Dom.get_value(#register_password))
        void
  end

  @client
  do_register(cbopt,_) =
    fname = String.trim( Dom.get_value(#register_first_name) )
    lname = String.trim( Dom.get_value(#register_last_name) )
    username = Utils.sanitize( Dom.get_value(#register_username) )
    password = Dom.get_value(#register_password)
    check_password = Dom.get_value(#check_password)
    level = AppConfig.default_level // FIXME
    teams = [] // FIXME
    if check_password != password then
      Notifications.error(@i18n("Registration"), <>{@i18n("Passwords do not match.")}</>)
    else
      AdminController.Async.register(fname, lname, username, password, level, teams, register_callback(cbopt, _))

  @server_private
  register(state, cb_opt) =
    if Admin.only_admin_can_register() &&
       not(Login.is_admin(state)) then <></>
    else
      domain = Admin.get_domain()
      <div id=#register class="form-wrap">{
        Form.wrapper(
          <div class="pane-heading">
            <h3>{AppText.register_new_account()}</h3>
          </div> <+>
          Form.line({Form.Default.line with label=@i18n("First name"); id="register_first_name"}) <+>
          Form.line({Form.Default.line with label=@i18n("Last name"); id="register_last_name"}) <+>
          Form.label(@i18n("Username (definitive)"), "register_username",
            <div class="input-group">
              <input id="register_username"
                  class="form-control" type="text"
                  required="required"></input><span class="input-group-addon">@{domain}</span>
            </div>) <+>
          Form.line({Form.Default.line with label=AppText.password(); id="register_password"; typ="password"; required=true}) <+>
          Form.line({Form.Default.line with label=@i18n("Repeat"); id="check_password"; typ="password"; required=true}) <+>
          <div class="form-group">{
            WB.Button.make({button=<>{AppText.register()}</> callback=do_register(cb_opt, _)}, [{primary}])
         }</div>
        , false)
      }
      </div>

  @client @async
  set_settings_callback =
  | {success=(timeout, grace_period, domain)} ->
    do Notifications.success(AppText.settings(), <>{@i18n("Timeout {timeout} minutes, Grace period {grace_period} seconds, Domain {domain}")}</>)
    void
  | {failure=e} ->
    do Notifications.error(AppText.settings(), <>{e}</>)
    void

  @client
  do_set_settings(_) =
    timeout = Dom.get_value(#disconnection_timeout)
    grace_period = Dom.get_value(#disconnection_grace_period)
    logo_name = Dom.get_value(#logo_name)
    domain_name = Dom.get_value(#domain_name)
    only_admin_can_register = Dom.is_checked(#only_admin_can_register)
    match (Parser.int(timeout),Parser.int(grace_period)) with
    | ({some=timeout},{some=grace_period}) ->
      settings = {
        disconnection_timeout = timeout
        disconnection_grace_period = grace_period
        domain = String.trim(domain_name)
        logo = String.trim(logo_name)
        only_admin_can_register = only_admin_can_register
      }
      AdminController.set_settings(settings, set_settings_callback)
    | _ -> Notifications.error(AppText.settings(), <>{@i18n("Invalid timeout or grace period")}</>)
    end

  @server_private
  build_disconnection_timeout(state) =
    logo_name = AdminController.get_logo_name()
    domain_name = AdminController.get_domain_name()
    timeout = AdminController.get_timeout()
    grace_period = AdminController.get_grace_period()
    register_enabled = Admin.only_admin_can_register()
    Utils.panel_default(
      Utils.panel_heading("PEPS") <+>
      Utils.panel_body(
        <form role="form">
          <div class="form-group">
            <label>{@i18n("Version")}</label>
            <p class="form-control-static">{peps_tag}</p>
          </div>
          <div class="form-group">
            <label>{@i18n("Hash")}</label>
            <p class="form-control-static">{peps_version}</p>
          </div>
        </form>
      )
    ) <+>
    Utils.panel_default(
      Utils.panel_heading(AppText.settings()) <+>
      Utils.panel_body(
        Form.wrapper(
          Form.line({Form.Default.line with label=@i18n("Logo name"); id="logo_name"; value=logo_name}) <+>
          Form.line({Form.Default.line with label=@i18n("Domain name"); id="domain_name"; value=domain_name}) <+>
          Form.label(
            @i18n("Disconnection timeout (in minutes)"), "disconnection_timeout",
            <input class="form-control" type="number" id=#disconnection_timeout value="{timeout}" min="10"></input>
          ) <+>
          Form.label(
            @i18n("Disconnection grace period (in seconds)"), "disconnection_grace_period",
            <input class="form-control" type="number" id=#disconnection_grace_period value="{grace_period}" min="10"></input>
          ) <+>
          <>
          <div class="form-group">
            <div class="checkbox">
              <label>
                { if register_enabled then
                    <input type="checkbox" id=#only_admin_can_register checked="checked"/>
                  else
                    <input type="checkbox" id=#only_admin_can_register/>
                } {@i18n("Only admin can register users")}
              </label>
            </div>
          </div>
          </> <+>
          <div class="form-group">{
            WB.Button.make({button=<>{AppText.save()}</> callback=do_set_settings}, [{primary}])
            |> Xhtml.add_attribute_unsafe("data-complete-text", AppText.save(), _)
            |> Xhtml.add_attribute_unsafe("data-loading-text", AppText.saving(), _)
            |> Xhtml.add_id(some("save_prefs_button"), _)
          }</div>
        , false)
    ))


  /** App methods. */
  App = {{

    /** Generic callback. */
    @private @client callback =
      | {failure=msg} -> Notifications.error(AppText.Apps(), <>{msg}</>)
      | _ ->
        do Dom.set_value(#new_app_name, "")
        do Dom.set_value(#new_app_provider, "")
        do Dom.set_value(#new_app_url, "")
        refresh()

    @private @both header =
      <thead><tr>
        <th></th>
        <th>{AppText.name()}</th><th>{AppText.Provider()}</th>
        <th>{AppText.Key()}</th><th>{AppText.Secret()}</th>
        <th></th>
      </tr></thead>

    /**
     * Validate an application's provider.
     * The provider must be either '*' or a valid
     * http url.
     */
    @private valid_http(addr) =
      addr == "*" ||
      match Uri.of_string(addr) with
      | {some=uri} -> Uri.is_valid_http(uri)
      | _ -> false
      end

    /** App creation. */
    @client create(_evt) =
      name = Dom.get_value(#new_app_name)
      provider = Dom.get_value(#new_app_provider) |> String.trim
      url = Dom.get_value(#new_app_url) |> String.trim
      if name != "" && url != "*" && valid_http(provider) && valid_http(url)
      then AdminController.App.create(name, provider, url, callback)
      else callback({failure=@i18n("Provider is not a valid HTTP address")})

    /** App deletion. */
    @client delete(key, _evt) =
      AdminController.App.delete(key,
        | {failure=msg} -> Notifications.error(AppText.Apps(), <>{msg}</>)
        | _ -> refresh()
      )

    /** Build the list of applications. */
    @both panel(apps) =
      rows = List.fold(app, list ->
        list <+>
        <tr>
          <td><span class="fa fa-lg {app.icon ? "fa-cube"}"></span></td>
          <td>{app.name}</td><td>{app.provider}</td>
          <td>{app.oauth_consumer_key}</td><td>{app.oauth_consumer_secret}</td>
          <td><a class="pull-right" onclick={delete(app.oauth_consumer_key, _)}
              rel="tooltip" title={AppText.delete()}>
            <i class="fa fa-trash-o"/>
          </a></td>
        </tr>, apps, <></>)
      body =
        if apps == []
        then <p class="form-control-static">{AppText.No_apps()}</p>
        else
          <table class="table">
            {header}
            <tbody>{rows}</tbody>
          </table>
      panel =
        <div class="panel panel-default">
          <div class="panel-heading">{AppText.Apps()}</div>
          <div class="panel-body">{body}</div>
        </div>
      panel

    /** Refresh the list of applications. */
    @client refresh() =
      apps = AdminController.App.list()
      panel = panel(apps)
      #inner_apps_panel <- panel

    /** Build the new app form. */
    @server_private build(state) =
      apps = @toplevel.App.list()
      list = panel(apps)
      <div id="apps_panel">
        <div id="inner_apps_panel">{list}</div>
        {Utils.panel_default(
          Utils.panel_heading(AppText.create()) <+>
          Utils.panel_body(
            Form.wrapper(
              Form.line({Form.Default.line with label=AppText.name(); id="new_app_name"; value=""}) <+>
              Form.line({Form.Default.line with label=AppText.Provider(); id="new_app_provider"; value=""}) <+>
              Form.line({Form.Default.line with label=AppText.link(); id="new_app_url"; value=""}) <+>
              <div class="form-group">{
                (WB.Button.make({button=<>{AppText.Create_app()}</> callback=create(_)}, [{primary}])
                 |> Xhtml.add_attribute_unsafe("data-complete-text", AppText.create(), _)
                 |> Xhtml.add_attribute_unsafe("data-loading-text", AppText.creating(), _)
                 |> Xhtml.add_id(some("create_app_button"), _))
              }</div>
            , false)
          ))}
      </div>

  }} // END APP


  // Bulk accounts

  @client
  do_bulk(_) =
    list = Dom.get_value(#bulk_accounts)
    // do Client.alert(%% BslPervasives.memdump %%(list)) // Xhtml.escape_special_chars
    lines = String.explode("\n", list)
    (valid, parse_errors) = List.foldi(
      (i, line, (valid, errors) ->
        fields = List.map(String.trim, String.explode_with(";", line, false))
        match fields
        [first, last, user, pass, level | teams] ->
          level = Parser.int(level) ? 1
          ((first, last, user, pass, level, teams) +> valid, errors)
        _ -> (valid, errors <+> <div class="alert alert-warning">{@i18n("Missing field at line {i}")}</div>)
      ), lines, ([], <></>)
    )
    do #bulk_parse_errors <- parse_errors
    AdminController.register_list(valid, (res ->
        match res
        {success=html} ->
          do #bulk_controller_errors <- html <+> <div class="alert alert-success">{AppText.Done()}</div>
          void
        {failure=html} ->
          void
      )
    )

  @server_private
  build_bulk(state) =
  Utils.panel_default(
    Utils.panel_heading(@i18n("Bulk import")) <+>
    Utils.panel_body(
      <div id="bulk_parse_errors"></div>
      <div id="bulk_controller_errors"></div>
      <form role="form">
        <div class="form-group">
          <p class="form-control-static">{@i18n("The passwords are optional, and will be automatically generated if needed.")}</p>
          <label>{@i18n("First name; Last name; Username; Password; Level; [Team1; Team2; ...]")}</label>
          <textarea id=#bulk_accounts rows="10" cols="80" class="form-control">
          </textarea>
        </div>
        <div class="form-group">
          {WB.Button.make({button=<>{AppText.create()}</> callback=do_bulk}, [{primary}])
            |> Xhtml.add_attribute_unsafe("data-complete-text", AppText.create(), _)
            |> Xhtml.add_attribute_unsafe("data-loading-text", AppText.creating(), _)
            |> Xhtml.add_id(some("bulk_button"), _)
          }
        </div>
      </form>
  ))

  /* Indexing */

  progress_section =
    // Can't get this to work...
    //<div id=#reindex_progress class="progress progress-success progress-striped active"
    //     role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="0">
    //  <div id=#reindex_progress_bar class="bar" style="width:0%;"></div>
    //</div>
    <div class="progress">
      <progress id=#reindex_progress_bar class="progress-bar progress-bar-success active" role="progressbar"
              max="100" value="0"></progress>
    </div>

  @client handle_progress(percent:int) =
    //Dom.set_style(Dom.select_raw_unsafe("#reindex_progress_bar"), [{width={percent=float_of_int(percent)}}])
    do Dom.set_value(#reindex_progress_bar, "{percent}")
    void

  @client finish_reindex(btn_id, _) =
    do Button.reset(#{btn_id})
    do Dom.hide(#reindex_progress_bar)
    //do Dom.set_style(Dom.select_raw_unsafe("#reindex_progress_bar"), [{width={percent=0.}}])
    do Dom.set_value(#reindex_progress_bar, "0")
    void

  @client finish_delete_index(btn_id, _) =
    do Button.reset(#{btn_id})
    void

  @publish @async do_reindexing_server(what, callback:(void -> void)) =
    do match what with
      | {messages} -> Search.Message.reindex(handle_progress)
      | {files} -> Search.File.reextract(handle_progress)
      | {users} -> Search.User.reindex(handle_progress)
      | {contacts} -> Search.rebook(handle_progress)
      end
    callback(void)

  @publish @async do_delete_indexing_server(what, callback:(void -> void)) =
    do ignore(match what with
      | {messages} -> Search.Message.clear()
      | {files} -> Search.File.clear()
      | {users} -> Search.User.clear()
      | {contacts} -> Search.delete_book()
      end)
    callback(void)

  @client
  do_reindexing(what, btn_id, _) =
    do Button.loading(#{btn_id})
    do Dom.show(#reindex_progress_bar)
    do do_reindexing_server(what, finish_reindex(btn_id, _))
    void

  @client
  do_delete_indexing(what, btn_id, _) =
    do Button.loading(#{btn_id})
    do do_delete_indexing_server(what, finish_delete_index(btn_id, _))
    void

  @server_private
  build_indexing(state) =
    Utils.panel_default(
      Utils.panel_heading(AppText.Indexing()) <+>
      Utils.panel_body(
        <form role="form">
          <div class="form-group">
            <p class="form-control-static text-info">{AppText.reindex_help()}</p>
            <p class="form-control-static">{AppText.reindex_help_small()}</p>
          </div>
          <div class="form-group">
            <label class="label-fw">{AppText.emails()}</label>{
            (WB.Button.make({button=<><span class="fa fa-repeat-circle-o"></span> {@i18n("Reindex")}</> callback=do_reindexing({messages},"reindex_mails_button",_)}, [{default}])
            |> Xhtml.add_attribute_unsafe("data-complete-text", @i18n("Reindex emails"), _)
            |> Xhtml.add_attribute_unsafe("data-loading-text", @i18n("Indexing emails..."), _)
            |> Xhtml.add_id(some("reindex_mails_button"), _)) <+>
            (WB.Button.make({button=<><span class="fa fa-trash-o"></span> {@i18n("Delete index")}</> callback=do_delete_indexing({messages},"delete_mails_button",_)}, [{default}])
            |> Xhtml.add_attribute_unsafe("data-complete-text", @i18n("Delete email index"), _)
            |> Xhtml.add_attribute_unsafe("data-loading-text", @i18n("Deleting email index..."), _)
            |> Xhtml.add_id(some("delete_mails_button"), _))
          }</div>
          <div class="form-group">
            <label class="label-fw">{AppText.files()}</label>{
            (WB.Button.make({button=<><span class="fa fa-repeat-circle-o"></span> {@i18n("Reindex")}</> callback=do_reindexing({files},"reindex_files_button",_)}, [{default}])
            |> Xhtml.add_attribute_unsafe("data-complete-text", @i18n("Reindex files"), _)
            |> Xhtml.add_attribute_unsafe("data-loading-text", @i18n("Indexing files..."), _)
            |> Xhtml.add_id(some("reindex_files_button"), _)) <+>
            (WB.Button.make({button=<><span class="fa fa-trash-o"></span> {@i18n("Delete index")}</> callback=do_delete_indexing({files},"delete_files_button",_)}, [{default}])
            |> Xhtml.add_attribute_unsafe("data-complete-text", @i18n("Delete files index"), _)
            |> Xhtml.add_attribute_unsafe("data-loading-text", @i18n("Deleting files index..."), _)
            |> Xhtml.add_id(some("delete_files_button"), _))
          }</div>
          <div class="form-group">
            <label class="label-fw">{AppText.users()}</label>{
            (WB.Button.make({button=<><span class="fa fa-repeat-circle-o"></span> {@i18n("Reindex")}</> callback=do_reindexing({users},"reindex_users_button",_)}, [{default}])
            |> Xhtml.add_attribute_unsafe("data-complete-text", @i18n("Reindex users"), _)
            |> Xhtml.add_attribute_unsafe("data-loading-text", @i18n("Indexing users..."), _)
            |> Xhtml.add_id(some("reindex_users_button"), _)) <+>
            (WB.Button.make({button=<><span class="fa fa-trash-o"></span> {@i18n("Delete index")}</> callback=do_delete_indexing({users},"delete_users_button",_)}, [{default}])
            |> Xhtml.add_attribute_unsafe("data-complete-text", @i18n("Delete users index"), _)
            |> Xhtml.add_attribute_unsafe("data-loading-text", @i18n("Deleting users index..."), _)
            |> Xhtml.add_id(some("delete_users_button"), _))
          }</div>
          <div class="form-group">
            <label class="label-fw">{AppText.contacts()}</label>{
            (WB.Button.make({button=<><span class="fa fa-repeat-circle-o"></span> {@i18n("Reindex")}</> callback=do_reindexing({contacts},"reindex_contacts_button",_)}, [{default}])
            |> Xhtml.add_attribute_unsafe("data-complete-text", @i18n("Reindex contacts"), _)
            |> Xhtml.add_attribute_unsafe("data-loading-text", @i18n("Indexing contacts..."), _)
            |> Xhtml.add_id(some("reindex_contacts_button"), _)) <+>
            (WB.Button.make({button=<><span class="fa fa-trash-o"></span> {@i18n("Delete index")}</> callback=do_delete_indexing({contacts},"delete_contacts_button",_)}, [{default}])
            |> Xhtml.add_attribute_unsafe("data-complete-text", @i18n("Delete contacts index"), _)
            |> Xhtml.add_attribute_unsafe("data-loading-text", @i18n("Deleting contacts index..."), _)
            |> Xhtml.add_id(some("delete_contacts_button"), _))
          }</div>
          <div class="form-group">
            {progress_section}
          </div>
        </form>
      ))

  @server
  build(state: Login.state, mode: string, path: Path.t) =
    Content.check_admin(state,
      match (mode) with
      | "settings" -> build_disconnection_timeout(state)
      | "classification" -> LabelView.build(state, true)
      | "indexing" -> build_indexing(state)
      | "bulk" -> build_bulk(state)
      | "apps" -> App.build(state)
      | _ -> Content.non_existent_resource
      end)

  /** Return the action associated with a mode. */
  @private
  action(mode: string) =
    // do log("Selected mode: {mode}")
    match (mode) with
    | "classification" ->
      [{
        text= @i18n("New class")
        action= LabelView.create(true, _)
        id= SidebarView.action_id
      }]
    | _ -> []

  /** {1} Construction of the sidebar. */
  Sidebar: Sidebar.sign = {{

    build(state, options, mode) =
      view = options.view
      onclick(mode) = Content.update_callback({mode= {admin=mode} path= []}, _)

      if (Login.is_super_admin(state)) then
        List.flatten(
          [ action(mode),
            [
              { name="settings"  id="settings" icon="gear-o"          title = AppText.settings()      onclick = onclick("settings") },
              { name="classes"   id="classes"  icon="tags-o"          title = @i18n("Classes")        onclick = onclick("classification") },
              { name="indexing"  id="indexing" icon="repeat-circle-o" title = AppText.Indexing()      onclick = onclick("indexing") },
              { name="bulk"      id="bulk"     icon="users-o"         title = @i18n("Bulk accounts")  onclick = onclick("bulk") },
              { name="apps"      id="apps"     icon="cube"            title = AppText.Apps()          onclick = onclick("apps") }
            ]
          ]
        )
      else []

  }} // END SIDEBAR

}}
