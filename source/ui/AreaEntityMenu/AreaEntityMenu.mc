import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// The entities of one area: its lights first, then its sensor readings. A light
// row is a native toggle showing the light's friendly name and on/off state;
// selecting it toggles the light, and the switch flips itself optimistically. A
// sensor row is a plain, inert row showing the reading as its sublabel. An area
// holding neither gets one inert row saying so.
//
// The menu renders from cached session state instantly. onShow is the
// navigation trigger: it fires a fresh state fetch and, when it returns,
// silently converges the visible rows to server truth without ever blocking on
// the network. Resume is handled separately by the app's onActive; onShow may
// also fire on resume, a tolerated harmless double-fetch.
class AreaEntityMenu extends WatchUi.Menu2 {
    private var _session as HomeSession;
    private var _lights as Array<String>;
    private var _sensors as Array<String>;

    function initialize(session as HomeSession, title as String, lights as Array<String>,
                        sensors as Array<String>) {
        Menu2.initialize({ :title => title });
        _session = session;
        _lights = lights;
        _sensors = sensors;

        // Not dead code, despite an area only reaching the payload when it holds
        // something: the area list's rows are built once and refresh never adds
        // or removes them, so a refresh that drops an area leaves a row that
        // still opens onto nothing.
        if (lights.size() == 0 && sensors.size() == 0) {
            addItem(new WatchUi.MenuItem(
                WatchUi.loadResource(Rez.Strings.NoEntitiesInArea) as String, null, :none, null));
            return;
        }
        for (var i = 0; i < lights.size(); i++) {
            addItem(buildItem(session, lights[i]));
        }
        for (var i = 0; i < sensors.size(); i++) {
            addItem(buildSensorItem(session, sensors[i]));
        }
    }

    function onShow() as Void {
        (Application.getApp() as HaControllerApp).setCurrentView(self);
        _session.refreshState(method(:redraw));
    }

    // The named redraw seam onActive dispatches to (see CardLoopView.redraw);
    // any new state-showing view implements it. Rows are updated in place and never
    // added, removed or reordered, so scroll and focus survive.
    function redraw() as Void {
        for (var i = 0; i < _lights.size(); i++) {
            var entityId = _lights[i];
            var index = findItemById(entityId);
            if (index < 0) {
                continue;
            }
            var item = getItem(index) as WatchUi.ToggleMenuItem;
            item.setEnabled(_session.isOn(entityId));
            item.setSubLabel(buildSubLabel(_session, entityId));
        }
        for (var i = 0; i < _sensors.size(); i++) {
            var entityId = _sensors[i];
            var index = findItemById(entityId);
            if (index < 0) {
                continue;
            }
            (getItem(index) as WatchUi.MenuItem).setSubLabel(buildReading(_session, entityId));
        }
        WatchUi.requestUpdate();
    }

    static function buildItem(session as HomeSession, entityId as String) as WatchUi.ToggleMenuItem {
        return new WatchUi.ToggleMenuItem(
            session.getName(entityId), buildSubLabel(session, entityId),
            entityId, session.isOn(entityId), null);
    }

    // A reading is a plain MenuItem, never a toggle: that is what makes the row
    // inert (see AreaEntityMenuDelegate.onSelect). It still carries the entity id, so
    // redraw can find it.
    static function buildSensorItem(session as HomeSession, entityId as String) as WatchUi.MenuItem {
        return new WatchUi.MenuItem(
            session.getName(entityId), buildReading(session, entityId), entityId, null);
    }

    // The single seam for a light row's sublabel: both construction and redraw
    // route through here, so the two never disagree on what a row shows.
    static function buildSubLabel(session as HomeSession, entityId as String) as String or Null {
        if (!session.isAvailable(entityId)) {
            var stringId = session.isGroup(entityId) ? Rez.Strings.GroupUnavailable : Rez.Strings.Unavailable;
            return WatchUi.loadResource(stringId) as String;
        }
        if (!session.isGroup(entityId)) {
            return null;
        }
        var count = session.getMemberCount(entityId);
        if (count == 1) {
            return WatchUi.loadResource(Rez.Strings.GroupLightCountOne) as String;
        }

        return Lang.format(WatchUi.loadResource(Rez.Strings.GroupLightCount) as String, [count]);
    }

    // The same seam for a sensor row: HA's own formatting, verbatim, or the
    // unavailable label when there is no value to trust.
    static function buildReading(session as HomeSession, entityId as String) as String {
        var reading = session.getReading(entityId);
        if (!session.isAvailable(entityId) || reading == null) {
            return WatchUi.loadResource(Rez.Strings.Unavailable) as String;
        }
        return reading as String;
    }
}
