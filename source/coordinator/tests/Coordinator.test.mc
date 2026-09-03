import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

(:test)
module CoordinatorTest {
    const ONE_ROOM = "{\"areas\":{\"area.room\":{\"name\":\"Room\"}}}";
    const TWO_ROOMS = "{\"areas\":{\"area.room\":{\"name\":\"Room\"},\"area.kitchen\":{\"name\":\"Kitchen\"}}}";
    const ONE_FLOOR = "{\"zone\":\"Home\",\"areas\":{\"area.room\":{\"name\":\"Room\"}},"
        + "\"floors\":{\"floor.ground\":{\"name\":\"Ground\",\"order\":0,\"areas\":[\"area.room\"]}}}";
    const ROOM_LIGHT_ON = "{\"home\":\"1/2\",\"lights\":{\"light.a\":{\"state\":true,\"area_id\":\"area.room\"}}}";
    const TWO_ROOMS_LIT = "{\"lights\":{\"light.a\":{\"state\":true,\"area_id\":\"area.room\"},"
        + "\"light.k\":{\"state\":true,\"area_id\":\"area.kitchen\"}}}";
    const ROOM_LIGHTS_ONE_ON = "{\"lights\":{\"light.a\":{\"state\":true,\"area_id\":\"area.room\"},"
        + "\"light.b\":{\"state\":false,\"area_id\":\"area.room\"}}}";
    const ROOM_LIGHTS_OFF = "{\"lights\":{\"light.a\":{\"state\":false,\"area_id\":\"area.room\"},"
        + "\"light.b\":{\"state\":false,\"area_id\":\"area.room\"}}}";
    const ROOM_FAN_ON = "{\"fans\":{\"fan.f\":{\"state\":true,\"area_id\":\"area.room\"}}}";
    const ROOM_SENSORS = "{\"home\":{\"temperature\":\"21 °C\",\"humidity\":\"40 %\"},"
        + "\"areas\":{\"area.room\":{\"temperature\":\"21 °C\"}},"
        + "\"sensors\":{\"sensor.t\":{\"friendly_state\":\"21 °C\",\"device_class\":\"temperature\",\"area_id\":\"area.room\"}}}";
    const EMPTY = "{}";

    function coordinatorWith(gateway as FakeRequestGateway, scheduler as FakeScheduler) as Coordinator {
        return coordinatorOn(new HaState(), gateway, scheduler);
    }

    function coordinatorOn(haState as HaState, gateway as FakeRequestGateway,
                           scheduler as FakeScheduler) as Coordinator {
        Application.Properties.setValue("haBaseUrl", "http://ha.local");
        Application.Properties.setValue("haToken", "token");
        var coordinator = new Coordinator(ClientFixture.clientWith(gateway, scheduler), haState, new FakeScheduler());
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
function eachFetchTargetLandsUnderItsOwnDomainAndFeedsTheGlance(logger as Test.Logger) as Boolean {
    var haState = new HaState();
    var coordinator = CoordinatorTest.coordinatorOn(haState, new FakeRequestGateway(), new FakeScheduler());

    coordinator.onFetchTarget(FetchTarget.STRUCTURE, JsonParser.parse(CoordinatorTest.ONE_ROOM), false);
    coordinator.onFetchTarget(FetchTarget.LIGHTS, JsonParser.parse(CoordinatorTest.ROOM_LIGHT_ON), false);
    coordinator.onFetchTarget(FetchTarget.FANS, JsonParser.parse(CoordinatorTest.ROOM_FAN_ON), false);
    coordinator.onFetchTarget(FetchTarget.SENSORS, JsonParser.parse(CoordinatorTest.ROOM_SENSORS), false);

    Test.assert(haState.getToggleablesInArea("area.room", Domain.LIGHT)[0].isOn());
    Test.assert(haState.getToggleablesInArea("area.room", Domain.FAN)[0].isOn());
    Test.assertEqual(GlanceSummary.getLightSummary() as String, "1/2");
    Test.assertEqual(GlanceSummary.getTemperature() as String, "21 °C");
    Test.assertEqual(GlanceSummary.getHumidity() as String, "40 %");
    return true;
}

(:test)
function aShownScreenIsRebuiltWhenItsStateChanges(logger as Test.Logger) as Boolean {
    var haState = CoordinatorTest.stateOf(CoordinatorTest.ONE_ROOM, CoordinatorTest.ROOM_LIGHT_ON, CoordinatorTest.EMPTY);
    var coordinator = CoordinatorTest.coordinatorOn(haState, new FakeRequestGateway(), new FakeScheduler());
    var loop = new CardLoop(coordinator, CardLoopBuilder.build(haState));
    coordinator.onViewShown(loop);
    Test.assertEqual(CardLoopTest.focusedId(loop), "area.room");

    coordinator.onFetchTarget(FetchTarget.STRUCTURE, JsonParser.parse(CoordinatorTest.TWO_ROOMS), false);
    coordinator.onFetchTarget(FetchTarget.LIGHTS, JsonParser.parse(CoordinatorTest.TWO_ROOMS_LIT), false);

    loop.showNext();
    Test.assertEqual(CardLoopTest.focusedId(loop), "area.kitchen");
    return true;
}

(:test)
function aTapOptimisticallyFlipsTheEntityUntilASecondTapIsRefused(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var haState = CoordinatorTest.stateOf(CoordinatorTest.ONE_ROOM, CoordinatorTest.ROOM_LIGHT_ON, CoordinatorTest.EMPTY);
    var coordinator = CoordinatorTest.coordinatorOn(haState, gateway, new FakeScheduler());

    coordinator.toggleEntity("light.a");
    Test.assert(!haState.isOn("light.a"));
    Test.assert(haState.isPending("light.a"));
    Test.assertEqual(gateway.count(), 1);

    coordinator.toggleEntity("light.a");
    Test.assert(!haState.isOn("light.a"));
    Test.assertEqual(gateway.count(), 1);
    return true;
}

(:test)
function togglingAFloorDrivesEveryLightOffWhileAnyIsOnAndOnOtherwise(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var oneOn = CoordinatorTest.stateOf(CoordinatorTest.ONE_FLOOR, CoordinatorTest.ROOM_LIGHTS_ONE_ON, CoordinatorTest.EMPTY);
    var onCoordinator = CoordinatorTest.coordinatorOn(oneOn, gateway, new FakeScheduler());

    onCoordinator.toggleFloorLights("floor.ground");
    Test.assert(!oneOn.hasAnyOn(oneOn.getToggleablesInFloor("floor.ground", Domain.LIGHT)));
    Test.assertEqual(gateway.count(), 1);

    var allOff = CoordinatorTest.stateOf(CoordinatorTest.ONE_FLOOR, CoordinatorTest.ROOM_LIGHTS_OFF, CoordinatorTest.EMPTY);
    var offCoordinator = CoordinatorTest.coordinatorOn(allOff, new FakeRequestGateway(), new FakeScheduler());

    offCoordinator.toggleFloorLights("floor.ground");
    var lights = allOff.getToggleablesInFloor("floor.ground", Domain.LIGHT);
    Test.assert(lights[0].isOn() && lights[1].isOn());
    return true;
}

(:test)
function aToggleRefreshesOnceItSettlesWhetherOrNotItFailed(logger as Test.Logger) as Boolean {
    var settled = new FakeRequestGateway();
    CoordinatorTest.coordinatorWith(settled, new FakeScheduler()).onToggleSettled(null);
    Test.assertEqual(settled.count(), 1);

    var failed = new FakeRequestGateway();
    CoordinatorTest.coordinatorWith(failed, new FakeScheduler())
        .onToggleSettled(new RequestError(-1, RequestType.REQUEST));
    Test.assertEqual(failed.count(), 1);
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
