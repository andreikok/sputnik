from collections import defaultdict
from twisted.internet.defer import inlineCallbacks, returnValue, DeferredList

import observatory

debug, log, warn, error, critical = observatory.get_loggers("plugin_manager")

class PluginException(Exception):
    pass

class PluginManager:
    def __init__(self):
        self.plugins = {}
        self.services = defaultdict(list)

    def load(self, path):
        module_name, class_name = path.rsplit(".", 1)
        mod = __import__(module_name)
        for component in module_name.split(".")[1:]:
            mod = getattr(mod, component)
        klass = getattr(mod, class_name)
        plugin = klass()
        plugin.module_name = module_name
        plugin.service_name = module_name.rsplit(".", 1)[0]
        plugin.class_name = class_name
        plugin.plugin_path = path
        plugin.manager = self
        return self._load_plugin(plugin)

    @inlineCallbacks
    def init(self, plugin):
        plugin = yield self._init_plugin(plugin)
        returnValue(plugin)

    @inlineCallbacks
    def shutdown(self, plugin):
        plugin = yield self._shutdown_plugin(plugin)
        returnValue(plugin)

    def unload(self, path):
        return self._unload_plugin(self.plugins[path])

    def _load_plugin(self, plugin):
        path = plugin.plugin_path
        debug("Loading plugin %s..." % path)
        if path in self.plugins:
            warn("Plugin %s already loaded." % path)
            return
        debug("Configuring plugin %s..." % path)
        plugin.configure()
        debug("Plugin %s loaded." % path)
        self.plugins[path] = plugin
        self.services[plugin.service_name].append(plugin)
        return plugin

    @inlineCallbacks
    def _init_plugin(self, plugin):
        path = plugin.plugin_path
        debug("Initializing plugin %s..." % path)
        try:
            yield plugin.init()
        except Exception, e:
            error("Unable to initialize plugin %s." % path)
            error(e)
            raise PluginException("Unable to initialize plugin %s." % path)
        debug("Plugin %s is ready." % path)
        returnValue(plugin)

    @inlineCallbacks
    def _shutdown_plugin(self, plugin):
        path = plugin.plugin_path
        debug("Shutting down plugin %s..." % path)
        try:
            yield plugin.shutdown()
        except Exception, e:
            error("Unable to shut down plugin %s." % path)
            error(e)
            raise PluginException("Unable to shut down plugin %s." % path)
        debug("Plugin %s is done." % path)
        returnValue(plugin)

    def _unload_plugin(self, plugin):
        path = plugin.plugin_path
        debug("Unloading plugin %s..." % path)
        if path not in self.plugins:
            warn("Plugin %s not loaded." % path)
            return
        if plugin in self.services[plugin.service_name]:
            self.services[plugin.service_name].remove(plugin)
        debug("Plugin %s unloaded." % path)

class Plugin:
    def __init__(self):
        pass

    def configure(self):
        pass

    def event(self, event_name, *args, **kwargs):
        method = getattr(self, "on_%s" % event_name)
        if callable(method):
            try:
                method(*args, **kwargs)
            except Exception as e:
                error("Exception in plugin %s event handler for %s." % \
                        (self.plugin_name, event_name))
                error(e)

    def init(self):
        pass

    def shutdown(self):
        pass

    def require(self, path):
        plugin = self.manager.plugins.get(path)
        if not plugin:
            raise PluginException("Plugin %s requires %s." % \
                    (self.plugin_path, path))
        return plugin

def run_with_plugins(plugin_paths, callback, *args, **kwargs):
    plugin_manager = PluginManager()
    plugins = [plugin_manager.load(plugin_path) for plugin_path in plugin_paths]
    deferreds = []
    for plugin in plugins:
        deferreds.append(plugin_manager.init(plugin))
    dl = DeferredList(deferreds)
    def run_callback(result):
        for success, value in result:
            if not success:
                error("Not all plugins loaded. Aborting.")
                return
        callback(plugin_manager, *args, **kwargs)
    @inlineCallbacks
    def cleanup(_):
        plugins.reverse()
        plugin_paths.reverse()
        for plugin in plugins:
            try:
                yield plugin_manager.shutdown(plugin)
            except Exception, e:
                pass
        for plugin_path in plugin_paths:
            plugin_manager.unload(plugin_path)
        returnValue(_)
    dl.addCallback(run_callback)
    dl.addBoth(cleanup)
    dl.addErrback(error)

