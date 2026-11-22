-- Run through run.py: all plugin code and Plenary process callbacks are real.
local options = vim.json.decode(vim.env.ZOXIDE_TEST_OPTIONS)
local root = vim.env.ZOXIDE_TEST_ROOT
vim.opt.rtp:prepend(options.plugin)
vim.opt.rtp:append(options.plenary)
if options.telescope then
  vim.opt.rtp:append(options.telescope)
end
vim.o.columns, vim.o.lines = 120, 40
local report = { nvim = tostring(vim.version()), checks = {}, notifications = {}, deprecations = {} }
local notify, deprecate = vim.notify, vim.deprecate
vim.notify = function(message, level, opts)
  table.insert(report.notifications, { message = tostring(message), level = level or 2, fast = vim.in_fast_event() })
  return notify(message, level, opts)
end
vim.deprecate = function(...)
  table.insert(report.deprecations, { ... })
  return deprecate(...)
end

local function check(condition, message)
  assert(condition, message)
  table.insert(report.checks, message)
end

local function await(predicate, message)
  assert(vim.wait(5000, predicate, 10), message)
end

local function calls()
  local result = {}
  for _, line in ipairs(vim.fn.readfile(root .. '/calls.jsonl')) do
    result[#result + 1] = vim.json.decode(line)
  end
  return result
end

local function add_count()
  local count = 0
  for _, call in ipairs(calls()) do
    if call[1] == 'add' then
      count = count + 1
    end
  end
  return count
end

local function reset_windows()
  vim.cmd('tabonly!')
  vim.cmd('only!')
  vim.cmd('cd ' .. vim.fn.fnameescape(root))
end

local ok, err = xpcall(function()
  local zoxide = require('zoxide')
  zoxide.setup({ path = options.fixture, define_commands = false })
  check(vim.fn.exists(':Z') == 0, 'define_commands=false leaves commands undefined')
  zoxide.setup({ path = options.fixture, define_commands = true })
  check(vim.fn.exists(':Z') == 2 and vim.fn.exists(':Zt') == 2 and vim.fn.exists(':Zw') == 2,
    'Z, Zt and Zw commands remain available')
  check(zoxide.get_config().path == options.fixture, 'Configured executable is used')

  -- A user callback is allowed to call an editor API on both success and error.
  for _, query in ipairs({ 'success', 'missing', 'empty' }) do
    local context = { mode = 'single', scope = 'global', query = query }
    local count, received, was_fast = 0, nil, nil
    local before = #report.notifications
    zoxide.zoxide(context, function(actual_context, directory)
      assert(actual_context == context, 'Callback context changed')
      count, received, was_fast = count + 1, directory, vim.in_fast_event()
      vim.api.nvim_buf_set_var(0, 'zoxide_callback_result', directory or 'none')
    end)
    await(function() return count > 0 end, 'Query callback did not complete: ' .. query)
    vim.wait(30, function() return false end)
    check(count == 1 and not was_fast, query .. ': callback runs once outside a fast event')
    if query == 'success' then
      check(received == root .. '/alpha' and #report.notifications == before,
        'Successful query returns its directory without warnings')
    else
      check(received == nil, query .. ': callback receives nil')
      local message = report.notifications[before + 1]
      check(#report.notifications == before + 1 and message.level == vim.log.levels.WARN and not message.fast,
        query .. ': one warning remains visible on the main loop')
      check(message.message:find(query == 'empty' and 'no matches found' or 'no matching directory', 1, true),
        query .. ': warning retains the failure details')
    end
  end

  local selection = vim.ui.select
  local selection_calls, choose = 0, 2
  vim.ui.select = function(items, opts, callback)
    assert(not vim.in_fast_event(), 'Selection UI called from fast event')
    assert(#items == 2 and opts.prompt == ':cd to...', 'Selection options changed')
    selection_calls = selection_calls + 1
    callback(choose and items[choose] or nil, choose)
  end
  for _, cancellation in ipairs({ false, true }) do
    if cancellation then choose = nil else choose = 2 end
    local count, result = 0, nil
    zoxide.zoxide({ mode = 'list', scope = 'global', query = 'multi' }, function(_, directory)
      assert(not vim.in_fast_event(), 'Selection callback called from fast event')
      count, result = count + 1, directory
      vim.api.nvim_buf_set_var(0, 'zoxide_selected', directory or 'cancelled')
    end)
    await(function() return count == 1 end, 'Selection did not complete')
    check(cancellation and result == nil or not cancellation and result == root .. '/beta',
      cancellation and 'Cancelling selection returns nil safely' or 'Multiple matches can select a directory')
  end
  check(selection_calls == 2, 'Multiple-result queries use the selection UI')
  local single_done = false
  zoxide.zoxide({ mode = 'list', scope = 'global', query = 'success' }, function(_, directory)
    single_done = directory == root .. '/alpha'
  end)
  await(function() return single_done end, 'Single result in list mode did not complete')
  check(selection_calls == 2, 'One result bypasses the selection UI')
  vim.ui.select = selection

  local before = #report.notifications
  zoxide.increment(root .. '/add-fail')
  await(function() return #report.notifications > before end, 'Failed add did not report its error')
  local warning = report.notifications[#report.notifications]
  check(warning.level == vim.log.levels.WARN and not warning.fast
    and warning.message:find('cannot write zoxide database', 1, true),
    'Failed add reports the database error safely')
  before = #report.notifications
  local previous_adds = add_count()
  zoxide.increment(root .. '/alpha')
  await(function() return add_count() > previous_adds end, 'Successful add did not execute')
  vim.wait(50, function() return false end)
  check(#report.notifications == before, 'Successful add does not emit a warning')

  reset_windows()
  vim.cmd('Z! success')
  await(function() return vim.fn.getcwd() == root .. '/alpha' end, 'Z! did not change directory')
  check(vim.fn.haslocaldir() == 0 and vim.fn.getcwd(-1, -1) == root .. '/alpha',
    'Z! changes the global working directory')
  for _, scope in ipairs({ 'tab', 'window' }) do
    reset_windows()
    vim.cmd('split')
    local other = vim.api.nvim_list_wins()[2]
    if other == vim.api.nvim_get_current_win() then other = vim.api.nvim_list_wins()[1] end
    vim.cmd(scope == 'tab' and 'Zt! success' or 'Zw! success')
    await(function() return vim.fn.getcwd() == root .. '/alpha' end, 'Scoped command did not complete')
    check(vim.fn.haslocaldir() == (scope == 'window' and 1 or 0)
      and vim.fn.haslocaldir(-1) == (scope == 'tab' and 1 or 0)
      and vim.fn.getcwd(-1, -1) == root,
      scope .. ': command preserves the global directory')
    local sibling_directory = vim.fn.getcwd(other, 0)
    check(sibling_directory == (scope == 'tab' and root .. '/alpha' or root),
      scope .. ': other window observes the correct directory scope')
  end
  reset_windows()
  before = #report.notifications
  vim.cmd('Z! missing')
  await(function() return #report.notifications > before end, 'Command failure was not reported')
  check(vim.fn.getcwd() == root, 'Failed command keeps the working directory')

  if options.telescope then
    local telescope = require('telescope')
    telescope.setup({ defaults = { layout_config = { width = 100, height = 30 } }, extensions = { zoxide = {} } })
    telescope.load_extension('zoxide')
    local state = require('telescope.actions.state')
    local actions = require('telescope.actions')
    for _, scope in ipairs({ 'global', 'tab', 'window' }) do
      reset_windows()
      local export = scope == 'global' and 'zoxide' or scope
      telescope.extensions.zoxide[export]()
      local prompt = vim.api.nvim_get_current_buf()
      local picker = state.get_current_picker(prompt)
      picker:set_prompt('success')
      await(function() return picker.manager and picker.manager:num_results() > 0 end,
        'Telescope finder did not return results')
      vim.wait(50, function() return false end)
      actions.select_default(prompt)
      await(function() return vim.fn.getcwd() == root .. '/alpha' end, 'Telescope selection did not change directory')
      check(vim.fn.haslocaldir() == (scope == 'window' and 1 or 0)
        and vim.fn.haslocaldir(-1) == (scope == 'tab' and 1 or 0),
        'Telescope ' .. scope .. ' picker changes the correct directory scope')
    end
  end

  vim.wait(100, function() return false end)
  local history = vim.api.nvim_exec2('messages', { output = true }).output
  check(not history:find('E%d+:') and not history:find('stack traceback'), 'No emitted editor errors or callback tracebacks')
  check(#report.deprecations == 0, 'No deprecated APIs called in these workflows')
  for _, message in ipairs(report.notifications) do
    assert(not message.fast and message.level == vim.log.levels.WARN, vim.inspect(message))
  end
end, debug.traceback)

report.passed = ok
report.error = not ok and err or nil
report.messages = vim.api.nvim_exec2('messages', { output = true }).output
report.errmsg = vim.v.errmsg
vim.fn.writefile({ vim.json.encode(report) }, options.output)
if ok then vim.cmd('qa!') else print(err); vim.cmd('cquit') end
