import {createReducer, on} from "@ngrx/store";
import {ShipState} from "../selectors/ship.selectors";
import * as ShipActions from "../actions/ship.actions";

export const initialState: ShipState = {
  ships: [],
  loading: false,
  error: null
}

export const shipReducers = createReducer(
  initialState,
  on(ShipActions.loadShips, (state, {}) => ({
      ...state,
      loading: true,
      error: null
  })),
  on(ShipActions.loadShipsSuccess, (state, {ships}) => ({
    ...state,
    ships: ships,
    loading: false,
    error: null
  })),
)
