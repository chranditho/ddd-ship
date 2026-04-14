import {createAction, props} from "@ngrx/store";
import {Ship} from "../../models/ship";

const shipActions = {
  loadShips: '[Ship] Load Ships',
  loadShipsSuccess: '[Ship] Load Ships Success',
  loadShipsFailed: '[Ship] Load Ships Failed',
  addShip: '[Ship] Add Ship',
  addShipSuccess: '[Ship] Add Ship Success',
  addShipFailure: '[Ship] Add Ship Failure',
}

export const loadShips = createAction(
  shipActions.loadShips
);

export const loadShipsSuccess = createAction(
  shipActions.loadShipsSuccess,
  props<{ships: Ship[]}>()
);

export const loadShipsFailed = createAction(
  shipActions.loadShipsFailed
);

export const addShipSuccess = createAction(
  shipActions.addShipSuccess,
  props<Ship>()
);

export const addShipFailure = createAction(
  shipActions.addShipFailure,
  props<{error: string}>()
);
