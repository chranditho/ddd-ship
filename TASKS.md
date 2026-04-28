# Interview Tasks

This backend is built with **Domain-Driven Design (DDD)** and **Hexagonal Architecture** (also known as Ports & Adapters). Before starting, take some time to explore the module structure:

| Module | Purpose |
|---|---|
| `domain` | Core business logic — aggregates, value objects, domain services, and all port interfaces |
| `driving-adapter` | Inbound adapters — REST controllers that call into driving ports |
| `driven-adapter` | Outbound adapters — JPA repositories, remote service clients |
| `application` | Spring Boot wiring, Flyway migrations |

A general rule of this architecture: **the `domain` module must not depend on any other module.** All infrastructure dependencies (Spring Data, HTTP clients, etc.) live in the adapters.

---

## Task 1: Complete a Shipping

### Background

A `Shipping` travels through the following states:

```
IDLE → PREPARING → SHIPPING → DONE
```

Currently the `IDLE → PREPARING` transition is triggered by `POST /web/ships/{shipId}/shippings` and `PREPARING → SHIPPING` is triggered by `PUT /web/ships/{shipId}/shippings`. However, **there is no way to complete a shipping** — the `SHIPPING → DONE` transition is missing entirely.

### Your Task

Implement the "complete shipping" feature as a full vertical slice through all layers.

#### 1. Domain — `Shipping` (`domain` module)

Add a `complete()` method to `Shipping` that:
- Transitions `shippingState` to `ShippingState.DONE`
- Throws an `IllegalStateException` if the shipping is not currently in state `SHIPPING`

#### 2. Domain — `Ship` aggregate (`domain` module)

Add a `completeShipping()` method to `Ship` that delegates to its `activeShipping`. Decide carefully: what should happen if there is no active shipping, or if the active shipping is in the wrong state?

#### 3. Driving Port (`domain` module)

Extend `ShippingManagementPort` with:

```kotlin
fun completeShipping(shipId: ShipId): ShippingDetailsDTO?
```

#### 4. Application Service (`domain` module)

Implement `completeShipping` in `ShippingManagementService`:
- Load the ship via `ShipRepositoryPort`
- Call `completeShipping()` on the aggregate
- Persist the updated shipping via `ShippingRepositoryPort`
- Return the `ShippingDetailsDTO`

#### 5. REST Controller (`driving-adapter` module)

Add a new endpoint to `ShipShippingController`:

```
PATCH /web/ships/{shipId}/shippings
```

It should return a `ShippingResponse` and respond with `404` if the ship is not found.

### Acceptance Criteria

- `PATCH /web/ships/{shipId}/shippings` completes a shipping that is in state `SHIPPING` and returns it with state `DONE`
- Calling it on a ship with no active shipping, or one in state `PREPARING`, results in an appropriate error
- After completion, a new shipping can be created for the same ship

---

## Task 2: Replace the Static Quote Lookup with an External API

### Background

When a shipping is released (`PUT /web/ships/{shipId}/shippings`), a `ShippingQuote` is attached to it. The quote is currently looked up from a static database table (`quotes`) using a `SailorsCode` — a value derived from the ship's cargo weight and the current minute:

```kotlin
// SailorsCode.kt
val codeValue = (currentWeight * LocalDateTime.now().minute).toInt().mod(14)
```

The `QuoteRepositoryPort` driven port abstracts this lookup:

```kotlin
interface QuoteRepositoryPort {
    fun getQuoteForSailorsCode(sailorsCode: SailorsCode): ShippingQuote
}
```

The existing adapter (`QuoteRepositoryAdapter` in the `driven-adapter` module) simply queries a local DB table by the code value.

### Your Task

Replace the static DB-based adapter with a new **HTTP adapter** that fetches a quote from an external quotes API. The public [ZenQuotes API](https://zenquotes.io/api/random) is a free option — it returns a random inspirational quote and needs no authentication:

```
GET https://zenquotes.io/api/random
```

Response shape:
```json
[{ "q": "The quote text", "a": "Author Name" }]
```

> If you prefer, you can use any other quotes API or mock one locally — the important part is the architectural change, not the specific API.

#### 1. New Driven Port for the Remote API (`domain` module)

Introduce a new driven port interface in `domain/src/main/kotlin/.../ports/driven/` that describes fetching a quote from a remote service. Keep it free of any HTTP or infrastructure concerns — it is a pure domain abstraction.

#### 2. HTTP Adapter (`driven-adapter` module)

Create a new `@Component` in the `driven-adapter` module that:
- Implements the new driven port
- Uses Spring's `RestClient` (or `RestTemplate`) to call the external API
- Maps the API response to a `ShippingQuote`
- Handles network/API errors gracefully — fall back to a sensible default quote rather than letting the release fail

#### 3. Wire It Up (`application` or `driven-adapter` module)

Make sure the new adapter is picked up by Spring and replaces the old `QuoteRepositoryAdapter`. The `QuoteRepositoryPort` interface and the `ShippingManagementService` **must not change** — only the adapter implementation is swapped.

#### 4. (Optional) Configuration

If the API base URL is hardcoded, consider externalising it to `application.yml` so it can be pointed at a mock server in tests.

### Acceptance Criteria

- Releasing a shipping (`PUT /web/ships/{shipId}/shippings`) returns a `ShippingResponse` whose `sailorsCode` field contains a quote fetched from the external API
- The static `quotes` table and `QuoteRepositoryAdapter` are no longer used for quote resolution
- `ShippingManagementService` and `QuoteRepositoryPort` are unchanged
- If the external API is unavailable, the release does not fail — it uses a fallback quote
