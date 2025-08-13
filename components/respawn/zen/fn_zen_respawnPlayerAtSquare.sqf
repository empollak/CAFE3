#include "../macros.hpp"
#define SQUARE_POLL_RATE 5

params ["_position", "_object"];

private _squarePos = _position;

if !(isNull curatorCamera) then
{
    private _camPos = getPosASL curatorCamera;
    private _results = lineIntersectsSurfaces [_camPos, _position, objNull, objNull, true, 1];

    if (count _results > 0) then
    {
        _squarePos = _results # 0 # 0;
    };
};
systemChat format ["position: %1, _squarePos: %2", _position, _squarePos];

private _headlessClients = entities "HeadlessClient_F";
private _humanPlayers = allPlayers - _headlessClients;
private _deadPlayers = _humanPlayers select {!alive _x};

if (count _deadPlayers <= 0) exitWith
{
    systemChat "No players are currently dead.";
};

private _playerNames = _deadPlayers apply {name _x};

private _dialogContent = 
[
    ["LIST", "Allow respawn of player", [_deadPlayers, _playerNames, 0, 10]]
];

f_fnc_respawnPlayerAtSquare = 
{
    params ["_square", "_player"];

    _player setVariable ["f_var_lastSquareRespawnAttempt", CBA_missionTime, true];
    
    systemChat format ["square pos %1, player name %2, type %3", ASLToAGL getPosASL _square, name _player, typeName _player];
    [ASLToAGL getPosASL _square, "Respawn square"] remoteExec ["f_fnc_allowImmediateRespawnLocal", _player];
    deleteVehicle _square;
};

f_fnc_onSquareTimeout = 
{
    params ["_square", "_player"];
    // Third condition taken from createRespawnSquare
    if (!alive _square 
        or (alive _player) 
        or ((_player getVariable ["f_var_lastSquareRespawnAttempt", 0]) > (CBA_missionTime - (MINIMUM_RESPAWN_DELAY + SQUARE_POLL_RATE + 1)))) exitWith {
            systemChat "Respawn failed. Player might be alive or respawned too often.";
        };

    [_square, _player] call f_fnc_respawnPlayerAtSquare;
};

private _onConfirm = 
{
    params ["_values", "_args"];

    private _toRespawn = _values # 0;
    systemChat format ["count: %1 isnil %2", count _values];
    if (isNull _toRespawn or !((_toRespawn) isEqualType player)) exitWith {systemChat "No player selected for respawn"};

    systemChat format ["Respawn square will respawn %1 in 5s.  Delete the square to cancel. type %2, equals object %3", name _toRespawn, typeName _toRespawn, _toRespawn isEqualType player];

    private _squarePos = _args select 0;

    systemChat format ["Square pos is %1", _squarePos];

    private _square = "VR_Area_01_square_1x1_yellow_F" createVehicle _squarePos;
    _square setPosASL (_squarePos vectorAdd [0,0,0.1]);

    

    
    getAssignedCuratorLogic player addCuratorEditableObjects [[_square], true];

    [
        {!alive _square},
        {},
        [_square, _toRespawn],
        5,
        f_fnc_onSquareTimeout
    ] call CBA_fnc_waitUntilAndExecute;
};

[
    "Allow immediate respawn",
    _dialogContent,
    _onConfirm,
    {},
    [_squarePos]
] call zen_dialog_fnc_create;


