import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

(:test)
module CoordinatorTest {
    const ONE_ROOM = "{\"areas\":{\"area.room\":{\"name\":\"Room\"}}}";
    const TWO_ROOMS = "{\"areas\":{\"area.room\":{\"name\":\"Room\"},\"area.kitchen\":{\"name\":\"Kitchen\"}}}";
    const ONE_FLOOR = "{\"zone\":\"Home\",\"areas\":{\"area.room\":{\"name\":\"Room\"}},"
        + "\"floors\":{\"floor.ground\":{\"name\":\"Ground\",\"order\":0,\"areas\":[\"area.room\"]}}}";
    const ROOM_LIGHT_ON = "{\"home\":\"1/2\",\"lights\":{\"light.a\":{\"state\":true,\"area_id\":\"area.room\"}}}";
    const ROOM_LIGHT_OFF = "{\"lights\":{\"light.a\":{\"state\":false,\"area_id\":\"area.room\"}}}";
    const TWO_ROOMS_LIT = "{\"lights\":{\"light.a\":{\"state\":true,\"area_id\":\"area.room\"},"
        + "\"light.k\":{\"state\":true,\"area_id\":\"area.kitchen\"}}}";
    const ROOM_LIGHTS_ONE_ON = "{\"lights\":{\"light.a\":{\"state\":true,\"area_id\":\"area.room\"},"
        + "\"light.b\":{\"state\":false,\"area_id\":\"area.room\"}}}";
    const ROOM_LIGHTS_OFF = "{\"lights\":{\"light.a\":{\"state\":false,\"area_id\":\"area.room\"},"
        + "\"light.b\":{\"state\":false,\"area_id\":\"area.room\"}}}";
    const ROOM_FAN_ON = "{\"fans\":{\"fan.f\":{\"state\":true,\"area_id\":\"area.room\"}}}";
    const ROOM_FAN_OFF = "{\"fans\":{\"fan.f\":{\"state\":false,\"area_id\":\"area.room\"}}}";
    const ROOM_SENSORS = "{\"home\":{\"temperature\":\"21 °C\",\"humidity\":\"40 %\"},"
        + "\"areas\":{\"area.room\":{\"temperature\":\"21 °C\"}},"
        + "\"sensors\":{\"sensor.t\":{\"friendly_state\":\"21 °C\",\"device_class\":\"temperature\",\"area_id\":\"area.room\"}}}";
    const EMPTY = "{}";

    function coordinatorWith(gateway as FakeRequestGateway, scheduler as FakeScheduler) as Coordinator {
        return coordinatorWithClicks(gateway, scheduler, new FakeScheduler());
    }

    function coordinatorWithClicks(gateway as FakeRequestGateway, scheduler as FakeScheduler,
                                   clickDebounce as FakeScheduler) as Coordinator {
        Application.Properties.setValue("haBaseUrl", "http://ha.local");
        Application.Properties.setValue("haToken", "token");
        var coordinator = new Coordinator(ClientFixture.clientWith(gateway, scheduler), clickDebounce);
        Registration.seed("some-id");
        return coordinator;
    }

    function completeRefresh(gateway as FakeRequestGateway, structure as String, lights as String,
                             fans as String, sensors as String) as Void {
        gateway.replyLast(200, ClientFixture.renderPayload(structure));
        gateway.replyLast(200, ClientFixture.renderPayload(lights));
        gateway.replyLast(200, ClientFixture.renderPayload(fans));
        gateway.replyLast(200, ClientFixture.renderPayload(sensors));
    }

    function exhaustRetries(gateway as FakeRequestGateway, scheduler as FakeScheduler) as Void {
        for (var attempt = 0; attempt < 3; attempt++) {
            gateway.replyLast(-1, null);
            scheduler.runScheduled();
        }
        gateway.replyLast(-1, null);
    }

    function stateOf(structure as String, lights as String, fans as String) as HaState {
        var haState = new HaState();
        var structurePayload = JsonParser.parse(structure);
        haState.setZone(HaPayload.parseZone(structurePayload));
        haState.setAreas(HaPayload.parseAreas(structurePayload));
        haState.setFloors(HaPayload.parseFloors(structurePayload));
        haState.setToggleables(Domain.LIGHT, HaPayload.parseLights(JsonParser.parse(lights)));
        haState.setToggleables(Domain.FAN, HaPayload.parseFans(JsonParser.parse(fans)));
        return haState;
    }

    function areaMenuOf(coordinator as Coordinator, haState as HaState) as AreaEntityMenu {
        var provider = new FakeSubLabelProvider();
        var model = AreaEntityMenuBuilder.build(haState, "area.room", provider) as AreaEntityMenuModel;
        return new AreaEntityMenu(coordinator, "area.room", model, provider);
    }

    function floorMenuOf(coordinator as Coordinator, haState as HaState) as FloorEntityMenu {
        var model = FloorEntityMenuBuilder.build(haState, "floor.ground") as FloorEntityMenuModel;
        return new FloorEntityMenu(coordinator, "floor.ground", model);
    }

    function isOn(menu as WatchUi.Menu2, index as Number) as Boolean {
        return (menu.getItem(index) as WatchUi.ToggleMenuItem).isEnabled();
    }
}

(:test)
function aRefreshWithNoConfigurationAsksNothingOfHomeAssistant(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var coordinator = CoordinatorTest.coordinatorWith(gateway, new FakeScheduler());
    Application.Properties.setValue("haToken", "");

    coordinator.onActivate();

    Test.assertEqual(gateway.count(), 0);
    return true;
}

(:test)
function eachFetchTargetLandsInTheStateTheCardLoopAndTheGlanceRead(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var coordinator = CoordinatorTest.coordinatorWith(gateway, new FakeScheduler());
    var loop = new CardLoop(coordinator, CardLoopBuilder.build(new HaState()));

    coordinator.onViewShown(loop);
    CoordinatorTest.completeRefresh(gateway, CoordinatorTest.ONE_FLOOR, CoordinatorTest.ROOM_LIGHT_ON,
        CoordinatorTest.EMPTY, CoordinatorTest.ROOM_SENSORS);

    Test.assertEqual(CardLoopTest.focusedId(loop), "floor.ground");
    loop.showNext();
    Test.assertEqual(CardLoopTest.focusedId(loop), "area.room");
    Test.assertEqual((loop.currentCard() as AreaCard).lights.on, 1);
    Test.assertEqual((loop.currentCard() as Card).readings[0].text, "21 °C");
    Test.assertEqual(GlanceSummary.getLightSummary() as String, "1/2");
    Test.assertEqual(GlanceSummary.getTemperature() as String, "21 °C");
    Test.assertEqual(GlanceSummary.getHumidity() as String, "40 %");
    return true;
}

(:test)
function lightsAndFansLandInTheRowsOfAnOpenMenu(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var coordinator = CoordinatorTest.coordinatorWith(gateway, new FakeScheduler());
    var menu = CoordinatorTest.areaMenuOf(coordinator,
        CoordinatorTest.stateOf(CoordinatorTest.ONE_ROOM, CoordinatorTest.ROOM_LIGHT_OFF, CoordinatorTest.ROOM_FAN_OFF));

    coordinator.onViewShown(menu);
    CoordinatorTest.completeRefresh(gateway, CoordinatorTest.ONE_ROOM, CoordinatorTest.ROOM_LIGHT_ON,
        CoordinatorTest.ROOM_FAN_ON, CoordinatorTest.EMPTY);

    Test.assert(CoordinatorTest.isOn(menu, 0));
    Test.assert(CoordinatorTest.isOn(menu, 1));
    return true;
}

(:test)
function aScreenStillOnDisplayIsRebuiltInPlace(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var coordinator = CoordinatorTest.coordinatorWith(gateway, new FakeScheduler());
    var loop = new CardLoop(coordinator, CardLoopBuilder.build(
        CoordinatorTest.stateOf(CoordinatorTest.ONE_ROOM, CoordinatorTest.ROOM_LIGHT_ON, CoordinatorTest.EMPTY)));

    coordinator.onActivate();
    CoordinatorTest.completeRefresh(gateway, CoordinatorTest.ONE_ROOM, CoordinatorTest.ROOM_LIGHT_ON,
        CoordinatorTest.EMPTY, CoordinatorTest.EMPTY);
    coordinator.onViewShown(loop);

    coordinator.onActivate();
    CoordinatorTest.completeRefresh(gateway, CoordinatorTest.TWO_ROOMS, CoordinatorTest.TWO_ROOMS_LIT,
        CoordinatorTest.EMPTY, CoordinatorTest.EMPTY);

    Test.assertEqual(CardLoopTest.focusedId(loop), "area.room");
    loop.showNext();
    Test.assertEqual(CardLoopTest.focusedId(loop), "area.kitchen");
    return true;
}

(:test)
function aToggleIsRefusedWhileItsTargetIsStillPending(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var coordinator = CoordinatorTest.coordinatorWith(gateway, new FakeScheduler());
    var menu = CoordinatorTest.areaMenuOf(coordinator,
        CoordinatorTest.stateOf(CoordinatorTest.ONE_ROOM, CoordinatorTest.ROOM_LIGHT_ON, CoordinatorTest.EMPTY));
    coordinator.onViewShown(menu);
    CoordinatorTest.completeRefresh(gateway, CoordinatorTest.ONE_ROOM, CoordinatorTest.ROOM_LIGHT_ON,
        CoordinatorTest.EMPTY, CoordinatorTest.EMPTY);

    coordinator.toggleEntity("light.a");

    Test.assertEqual(gateway.count(), 5);
    Test.assertEqual(ClientFixture.sentService(gateway, 4), "toggle");
    Test.assert(!CoordinatorTest.isOn(menu, 0));

    coordinator.toggleEntity("light.a");

    Test.assertEqual(gateway.count(), 5);
    Test.assert(!CoordinatorTest.isOn(menu, 0));
    return true;
}

(:test)
function toggleFloorLightsTurnsTheFloorOffWhileAnyLightIsOnAndOnOtherwise(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var coordinator = CoordinatorTest.coordinatorWith(gateway, new FakeScheduler());
    var menu = CoordinatorTest.floorMenuOf(coordinator,
        CoordinatorTest.stateOf(CoordinatorTest.ONE_FLOOR, CoordinatorTest.ROOM_LIGHTS_ONE_ON, CoordinatorTest.EMPTY));
    coordinator.onViewShown(menu);
    CoordinatorTest.completeRefresh(gateway, CoordinatorTest.ONE_FLOOR, CoordinatorTest.ROOM_LIGHTS_ONE_ON,
        CoordinatorTest.EMPTY, CoordinatorTest.EMPTY);

    coordinator.toggleFloorLights("floor.ground");

    Test.assertEqual(ClientFixture.sentService(gateway, 4), "turn_off");
    Test.assert(!CoordinatorTest.isOn(menu, 0));

    gateway.replyLast(200, null);
    CoordinatorTest.completeRefresh(gateway, CoordinatorTest.ONE_FLOOR, CoordinatorTest.ROOM_LIGHTS_OFF,
        CoordinatorTest.EMPTY, CoordinatorTest.EMPTY);
    coordinator.toggleFloorLights("floor.ground");

    Test.assertEqual(ClientFixture.sentService(gateway, 9), "turn_on");
    Test.assert(CoordinatorTest.isOn(menu, 0));
    return true;
}

(:test)
function aSingleClickTogglesOnlyOnceTheDoubleClickWindowElapses(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var clicks = new FakeScheduler();
    var coordinator = CoordinatorTest.coordinatorWithClicks(gateway, new FakeScheduler(), clicks);
    coordinator.onActivate();
    CoordinatorTest.completeRefresh(gateway, CoordinatorTest.ONE_ROOM, CoordinatorTest.ROOM_LIGHT_ON,
        CoordinatorTest.EMPTY, CoordinatorTest.EMPTY);

    coordinator.onEntityClick("light.a");
    Test.assertEqual(gateway.count(), 4);

    clicks.runScheduled();
    Test.assertEqual(ClientFixture.sentService(gateway, 4), "toggle");
    return true;
}

(:test)
function aDoubleClickCancelsTheToggleAndCommandsNothing(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var clicks = new FakeScheduler();
    var coordinator = CoordinatorTest.coordinatorWithClicks(gateway, new FakeScheduler(), clicks);
    coordinator.onActivate();
    CoordinatorTest.completeRefresh(gateway, CoordinatorTest.ONE_ROOM, CoordinatorTest.ROOM_LIGHT_ON,
        CoordinatorTest.EMPTY, CoordinatorTest.EMPTY);

    coordinator.onEntityClick("light.a");
    coordinator.onEntityClick("light.a");
    clicks.runScheduled();

    Test.assertEqual(gateway.count(), 4);
    return true;
}

(:test)
function clickingASecondEntityFlushesTheFirstAsASingleClick(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var clicks = new FakeScheduler();
    var coordinator = CoordinatorTest.coordinatorWithClicks(gateway, new FakeScheduler(), clicks);
    coordinator.onActivate();
    CoordinatorTest.completeRefresh(gateway, CoordinatorTest.ONE_ROOM, CoordinatorTest.ROOM_LIGHTS_ONE_ON,
        CoordinatorTest.EMPTY, CoordinatorTest.EMPTY);

    coordinator.onEntityClick("light.a");
    coordinator.onEntityClick("light.b");

    Test.assertEqual(ClientFixture.sentService(gateway, 4), "toggle");
    Test.assertEqual(ClientFixture.sentField(gateway, 4, "entity_id") as String, "light.a");
    return true;
}

(:test)
function settingAnAttributeCommandsTheServiceAndAssumesTheValue(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var coordinator = CoordinatorTest.coordinatorWith(gateway, new FakeScheduler());
    var haState = CoordinatorTest.stateOf(CoordinatorTest.ONE_ROOM,
        "{\"lights\":{\"light.a\":{\"state\":true,\"area_id\":\"area.room\",\"brightness\":20}}}",
        CoordinatorTest.EMPTY);
    var menu = CoordinatorTest.areaMenuOf(coordinator, haState);
    coordinator.onViewShown(menu);
    CoordinatorTest.completeRefresh(gateway, CoordinatorTest.ONE_ROOM,
        "{\"lights\":{\"light.a\":{\"state\":true,\"area_id\":\"area.room\",\"brightness\":20}}}",
        CoordinatorTest.EMPTY, CoordinatorTest.EMPTY);

    var attribute = new AdjustableAttribute("light.a", Rez.Strings.AttrBrightness, Domain.LIGHT,
        "turn_on", null, "brightness_pct", Rez.Strings.Percent, new LevelRange(0, 100, 10), 20, null);
    coordinator.setAttribute(attribute, 73);

    Test.assertEqual(ClientFixture.sentService(gateway, 4), "turn_on");
    Test.assertEqual(ClientFixture.sentField(gateway, 4, "brightness_pct") as Number, 73);
    Test.assertEqual(AreaEntityMenuTest.itemOf(menu, "light.a").getSubLabel() as String, "73 %");
    return true;
}

(:test)
function settingFanSpeedTurnsItOnAboveZeroAndOffAtZero(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var coordinator = CoordinatorTest.coordinatorWith(gateway, new FakeScheduler());
    coordinator.onActivate();
    CoordinatorTest.completeRefresh(gateway, CoordinatorTest.ONE_ROOM, CoordinatorTest.EMPTY,
        CoordinatorTest.ROOM_FAN_OFF, CoordinatorTest.EMPTY);

    var speed = new AdjustableAttribute("fan.f", Rez.Strings.AttrSpeed, Domain.FAN, "turn_on",
        "set_percentage", "percentage", Rez.Strings.Percent, new LevelRange(0, 100, 10), 0, null);

    coordinator.setAttribute(speed, 50);
    Test.assertEqual(ClientFixture.sentService(gateway, 4), "turn_on");

    gateway.replyLast(200, null);
    CoordinatorTest.completeRefresh(gateway, CoordinatorTest.ONE_ROOM, CoordinatorTest.EMPTY,
        CoordinatorTest.ROOM_FAN_ON, CoordinatorTest.EMPTY);
    coordinator.setAttribute(speed, 0);

    Test.assertEqual(ClientFixture.sentService(gateway, 9), "set_percentage");
    return true;
}

(:test)
function aSettledToggleRefreshes(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var coordinator = CoordinatorTest.coordinatorWith(gateway, new FakeScheduler());
    coordinator.onActivate();
    CoordinatorTest.completeRefresh(gateway, CoordinatorTest.ONE_ROOM, CoordinatorTest.ROOM_LIGHT_ON,
        CoordinatorTest.EMPTY, CoordinatorTest.EMPTY);

    coordinator.toggleEntity("light.a");
    gateway.replyLast(200, null);

    Test.assertEqual(gateway.count(), 6);
    return true;
}

(:test)
function aFailedToggleStillRefreshes(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var scheduler = new FakeScheduler();
    var coordinator = CoordinatorTest.coordinatorWith(gateway, scheduler);
    coordinator.onActivate();
    CoordinatorTest.completeRefresh(gateway, CoordinatorTest.ONE_ROOM, CoordinatorTest.ROOM_LIGHT_ON,
        CoordinatorTest.EMPTY, CoordinatorTest.EMPTY);

    coordinator.toggleEntity("light.a");
    CoordinatorTest.exhaustRetries(gateway, scheduler);

    Test.assertEqual(gateway.count(), 9);
    return true;
}

(:test)
function aShownScreenRefreshesBeforeAnyDataHasLoadedButNotOverFreshData(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var coordinator = CoordinatorTest.coordinatorWith(gateway, new FakeScheduler());
    var loop = new CardLoop(coordinator, CardLoopBuilder.build(new HaState()));

    coordinator.onViewShown(loop);
    Test.assertEqual(gateway.count(), 1);

    CoordinatorTest.completeRefresh(gateway, CoordinatorTest.ONE_ROOM, CoordinatorTest.ROOM_LIGHT_ON,
        CoordinatorTest.EMPTY, CoordinatorTest.EMPTY);
    coordinator.onViewShown(loop);

    Test.assertEqual(gateway.count(), 4);
    return true;
}
