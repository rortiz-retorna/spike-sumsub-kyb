# Technical Design: Compliance Engine

## Project Overview

**Framework**: NestJS
**Architecture**: Domain-Driven Design (DDD) + Hexagonal Architecture
**Testing Strategy**: Test-Driven Development (TDD)
**Team**: Core Reporting (Compliance)

### Scope

The Compliance Engine is responsible for orchestrating identity verification and compliance checks for individuals (KYC) and businesses (KYB). Future capabilities may include AML screening, sanctions checks, and ongoing monitoring.

---

## 1. Naming Convention

This project follows the Core Reporting team's naming conventions. Three naming options are presented:

### Option 1: Classic (Descriptive)

**Project Name**: `compliance-engine`

| Resource | Convention | Example |
|----------|------------|---------|
| Repository | kebab-case | `compliance-engine` |
| NestJS Modules | PascalCase | `KybModule`, `KycModule`, `VerificationModule` |
| Database | snake_case | `compliance_db` (shared Retorna DB) |
| Jira Epic | `[COMPLIANCE] ...` | `[COMPLIANCE] KYB/KYC Verification Engine` |

**Pros**: Self-explanatory, no mythology knowledge required.
**Cons**: Generic, less memorable.

---

### Option 2: Themis (Recommended)

**Project Name**: `themis-compliance-engine`

> **Themis**: Greek Titaness of divine law, order, and justice. Depicted holding the scales of justice, she represents rules, fairness, and proper conduct. In mythology, she was the counselor to Zeus on matters of law and order.

| Resource | Convention | Example |
|----------|------------|---------|
| Repository | kebab-case | `themis-compliance-engine` |
| NestJS Modules | PascalCase | `KybModule`, `KycModule`, `VerificationModule` |
| Database schema | snake_case | `themis.verification_requests` |
| Jira Epic | `[THEMIS] ...` | `[THEMIS] KYB/KYC Verification Engine` |
| API Base Path | kebab-case | `/api/v1/themis/kyb/...` or `/api/v1/kyb/...` |

**Why Themis?**
- Directly represents compliance: **ensuring entities follow rules**
- Widely recognized symbol (scales of justice)
- Easy to pronounce and remember
- Consistent with team's Greek mythology convention (Hermes)

**Pros**: Meaningful, memorable, follows team convention.
**Cons**: Requires brief explanation for new team members.

---

### Option 3: Argus

**Project Name**: `argus-compliance-engine`

> **Argus Panoptes**: The all-seeing giant in Greek mythology, described as having 100 eyes. He was appointed by Hera to watch over Io, never sleeping with all eyes closed. Represents eternal vigilance and watchfulness.

| Resource | Convention | Example |
|----------|------------|---------|
| Repository | kebab-case | `argus-compliance-engine` |
| NestJS Modules | PascalCase | `KybModule`, `KycModule`, `VerificationModule` |
| Database schema | snake_case | `argus.verification_requests` |
| Jira Epic | `[ARGUS] ...` | `[ARGUS] KYB/KYC Verification Engine` |
| API Base Path | kebab-case | `/api/v1/argus/kyb/...` or `/api/v1/kyb/...` |

**Why Argus?**
- Emphasizes **watchfulness and verification**: "sees everything"
- Appropriate for identity verification (scrutinizing documents, detecting fraud)
- Strong imagery of vigilance and monitoring
- Consistent with team's Greek mythology convention (Hermes)

**Pros**: Evokes vigilance and thorough verification.
**Cons**: Less directly tied to "compliance/justice" concept.

---

### Comparison Summary

| Aspect | compliance-engine | themis | argus |
|--------|-------------------|--------|-------|
| **Meaning** | Descriptive | Law & Justice | Watchfulness |
| **Memorability** | Low | High | High |
| **Team Convention** | No | Yes (Greek) | Yes (Greek) |
| **Best For** | Generic compliance | Rule enforcement | Verification/monitoring |

**Recommendation**: **Themis** — best balance of meaning, memorability, and alignment with Core Reporting's naming convention.

---

## 2. Project Structure

```
compliance-engine/
├── src/
│   ├── main.ts
│   ├── app.module.ts
│   │
│   ├── shared/                          # Shared kernel
│   │   ├── shared.module.ts
│   │   ├── domain/
│   │   │   ├── value-objects/
│   │   │   │   ├── uuid.vo.ts
│   │   │   │   ├── email.vo.ts
│   │   │   │   └── country-code.vo.ts
│   │   │   ├── entities/
│   │   │   │   └── base.entity.ts
│   │   │   └── events/
│   │   │       └── domain-event.interface.ts
│   │   ├── application/
│   │   │   ├── ports/
│   │   │   │   ├── logger.port.ts
│   │   │   │   └── event-publisher.port.ts
│   │   │   └── exceptions/
│   │   │       ├── domain.exception.ts
│   │   │       └── application.exception.ts
│   │   └── infrastructure/
│   │       ├── config/
│   │       │   └── database.config.ts
│   │       ├── persistence/
│   │       │   └── typeorm/
│   │       │       └── base.repository.ts
│   │       └── logging/
│   │           └── pino-logger.adapter.ts
│   │
│   ├── verification/                    # Core verification bounded context
│   │   ├── verification.module.ts
│   │   │
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── verification-provider.entity.ts
│   │   │   │   ├── verification-subject.entity.ts
│   │   │   │   ├── verification-request.entity.ts
│   │   │   │   └── verification-event.entity.ts
│   │   │   ├── value-objects/
│   │   │   │   ├── subject-type.vo.ts
│   │   │   │   ├── verification-status.vo.ts
│   │   │   │   ├── verification-event-type.vo.ts
│   │   │   │   ├── rejection-reason.vo.ts
│   │   │   │   └── external-id.vo.ts
│   │   │   ├── events/
│   │   │   │   ├── verification-created.event.ts
│   │   │   │   ├── verification-status-changed.event.ts
│   │   │   │   └── verification-completed.event.ts
│   │   │   ├── exceptions/
│   │   │   │   ├── active-verification-exists.exception.ts
│   │   │   │   ├── verification-already-completed.exception.ts
│   │   │   │   └── invalid-status-transition.exception.ts
│   │   │   └── services/
│   │   │       ├── verification-domain.service.ts
│   │   │       └── webhook-idempotency.service.ts
│   │   │
│   │   ├── application/
│   │   │   ├── ports/
│   │   │   │   ├── inbound/
│   │   │   │   │   ├── initiate-verification.port.ts
│   │   │   │   │   ├── get-verification-status.port.ts
│   │   │   │   │   └── process-webhook.port.ts
│   │   │   │   └── outbound/
│   │   │   │       ├── verification-provider.port.ts
│   │   │   │       ├── verification-subject.repository.port.ts
│   │   │   │       ├── verification-request.repository.port.ts
│   │   │   │       ├── verification-event.repository.port.ts
│   │   │   │       └── processed-webhook.repository.port.ts
│   │   │   ├── use-cases/
│   │   │   │   ├── initiate-verification.use-case.ts
│   │   │   │   ├── get-verification-status.use-case.ts
│   │   │   │   ├── process-webhook.use-case.ts
│   │   │   │   └── regenerate-verification-url.use-case.ts
│   │   │   ├── dtos/
│   │   │   │   ├── initiate-verification.dto.ts
│   │   │   │   ├── verification-response.dto.ts
│   │   │   │   └── webhook-payload.dto.ts
│   │   │   └── mappers/
│   │   │       └── verification.mapper.ts
│   │   │
│   │   └── infrastructure/
│   │       ├── http/
│   │       │   ├── controllers/
│   │       │   │   └── webhook.controller.ts
│   │       │   ├── guards/
│   │       │   │   └── webhook-signature.guard.ts
│   │       │   └── interceptors/
│   │       │       └── raw-body.interceptor.ts
│   │       ├── persistence/
│   │       │   ├── typeorm/
│   │       │   │   ├── entities/
│   │       │   │   │   ├── verification-provider.orm-entity.ts
│   │       │   │   │   ├── verification-subject.orm-entity.ts
│   │       │   │   │   ├── verification-request.orm-entity.ts
│   │       │   │   │   ├── verification-event.orm-entity.ts
│   │       │   │   │   └── processed-webhook.orm-entity.ts
│   │       │   │   ├── repositories/
│   │       │   │   │   ├── verification-subject.typeorm.repository.ts
│   │       │   │   │   ├── verification-request.typeorm.repository.ts
│   │       │   │   │   ├── verification-event.typeorm.repository.ts
│   │       │   │   │   └── processed-webhook.typeorm.repository.ts
│   │       │   │   └── mappers/
│   │       │   │       ├── verification-subject.orm-mapper.ts
│   │       │   │       ├── verification-request.orm-mapper.ts
│   │       │   │       └── verification-event.orm-mapper.ts
│   │       │   └── migrations/
│   │       │       └── 1700000000000-create-verification-tables.ts
│   │       └── providers/
│   │           └── sumsub/
│   │               ├── sumsub.adapter.ts
│   │               ├── sumsub.config.ts
│   │               ├── sumsub.types.ts
│   │               └── mappers/
│   │                   ├── sumsub-status.mapper.ts
│   │                   └── sumsub-rejection.mapper.ts
│   │
│   ├── kyb/                             # KYB bounded context
│   │   ├── kyb.module.ts
│   │   │
│   │   ├── domain/
│   │   │   ├── value-objects/
│   │   │   │   ├── company-id.vo.ts
│   │   │   │   └── kyb-level.vo.ts
│   │   │   └── services/
│   │   │       └── kyb-domain.service.ts
│   │   │
│   │   ├── application/
│   │   │   ├── ports/
│   │   │   │   └── inbound/
│   │   │   │       ├── initiate-kyb.port.ts
│   │   │   │       └── get-kyb-status.port.ts
│   │   │   ├── use-cases/
│   │   │   │   ├── initiate-kyb.use-case.ts
│   │   │   │   └── get-kyb-status.use-case.ts
│   │   │   └── dtos/
│   │   │       ├── initiate-kyb.dto.ts
│   │   │       └── kyb-response.dto.ts
│   │   │
│   │   └── infrastructure/
│   │       └── http/
│   │           ├── controllers/
│   │           │   └── kyb.controller.ts
│   │           └── decorators/
│   │               └── kyb-api.decorator.ts
│   │
│   └── kyc/                             # KYC bounded context
│       ├── kyc.module.ts
│       │
│       ├── domain/
│       │   ├── value-objects/
│       │   │   ├── individual-id.vo.ts
│       │   │   └── kyc-level.vo.ts
│       │   └── services/
│       │       └── kyc-domain.service.ts
│       │
│       ├── application/
│       │   ├── ports/
│       │   │   └── inbound/
│       │   │       ├── initiate-kyc.port.ts
│       │   │       └── get-kyc-status.port.ts
│       │   ├── use-cases/
│       │   │   ├── initiate-kyc.use-case.ts
│       │   │   └── get-kyc-status.use-case.ts
│       │   └── dtos/
│       │       ├── initiate-kyc.dto.ts
│       │       └── kyc-response.dto.ts
│       │
│       └── infrastructure/
│           └── http/
│               ├── controllers/
│               │   └── kyc.controller.ts
│               └── decorators/
│                   └── kyc-api.decorator.ts
│
├── test/
│   ├── unit/
│   │   ├── verification/
│   │   │   ├── domain/
│   │   │   │   └── verification-request.entity.spec.ts
│   │   │   └── application/
│   │   │       └── initiate-verification.use-case.spec.ts
│   │   ├── kyb/
│   │   │   └── application/
│   │   │       └── initiate-kyb.use-case.spec.ts
│   │   └── kyc/
│   │       └── application/
│   │           └── initiate-kyc.use-case.spec.ts
│   │
│   ├── integration/
│   │   ├── verification/
│   │   │   ├── verification.integration.spec.ts
│   │   │   └── webhook.integration.spec.ts
│   │   └── fixtures/
│   │       └── sumsub-webhook.fixtures.ts
│   │
│   └── e2e/
│       ├── kyb.e2e-spec.ts
│       ├── kyc.e2e-spec.ts
│       └── webhook.e2e-spec.ts
│
├── libs/                                # Shared libraries (optional)
│   └── contracts/
│       └── src/
│           ├── compliance.contracts.ts
│           └── index.ts
│
├── docker-compose.yml
├── Dockerfile
├── nest-cli.json
├── tsconfig.json
├── tsconfig.build.json
├── package.json
└── README.md
```

---

## 3. Module Architecture

### 3.1 Module Dependency Graph

```
┌─────────────────────────────────────────────────────────────────┐
│                         app.module.ts                           │
│                       (compliance-engine)                       │
└─────────────────────────────────────────────────────────────────┘
                                │
                ┌───────────────┴───────────────┐
                │                               │
                ▼                               ▼
        ┌───────────────┐               ┌───────────────┐
        │  kyb.module   │               │  kyc.module   │
        │  (business)   │               │ (individual)  │
        └───────────────┘               └───────────────┘
                │                               │
                └───────────────┬───────────────┘
                                │
                                ▼
                ┌───────────────────────────────┐
                │     verification.module       │◄──── Core bounded context
                │  (includes webhook handling)  │
                └───────────────────────────────┘
                                │
                        ┌───────┴───────┐
                        │               │
                        ▼               ▼
                ┌───────────┐   ┌───────────────┐
                │  shared   │   │   (Sumsub)    │
                │  .module  │   │   Adapter     │
                └───────────┘   └───────────────┘


┌─────────────────────────────────────────────────────────────────┐
│                    EXTERNAL DEPENDENCY                          │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              notification-service                         │  │
│  │         (Owned by: core-payments team)                    │  │
│  │                                                           │  │
│  │  - Email automation (immediate + reminders)               │  │
│  │  - SQS queue consumption                                  │  │
│  │  - Template management                                    │  │
│  │                                                           │  │
│  │  Integration: compliance-engine publishes events/messages │  │
│  │  to SQS, notification-service consumes and sends emails.  │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Module Responsibilities

| Module | Responsibility |
|--------|----------------|
| `shared` | Shared kernel: base entities, value objects, exceptions, logging |
| `verification` | Core verification logic, provider abstraction, status management, webhook handling |
| `kyb` | Business verification facade, company-specific rules and API |
| `kyc` | Individual verification facade, person-specific rules and API |

### 3.3 External Dependencies

| Service | Team | Integration |
|---------|------|-------------|
| `notification-service` | core-payments | SQS messages for email triggers |

> **Note**: Email automation (immediate notifications + scheduled reminders) will be handled by the `notification-service` owned by the **core-payments** team. The compliance-engine publishes verification events to an SQS queue; the notification-service consumes these messages and handles email delivery.

---

## 4. Domain Layer Design

### 4.1 Entities

```typescript
// verification/domain/entities/verification-subject.entity.ts

export class VerificationSubject extends BaseEntity {
  private readonly _id: UUID;
  private readonly _externalId: ExternalId;
  private readonly _subjectType: SubjectType;
  private readonly _countryCode: CountryCode;
  private readonly _providerId: UUID;
  private _providerSubjectId: string | null;

  // Factory method
  static create(props: CreateSubjectProps): VerificationSubject;

  // Domain methods
  assignProviderSubjectId(providerSubjectId: string): void;

  // Getters
  get id(): UUID;
  get externalId(): ExternalId;
  get subjectType(): SubjectType;
  get isCompany(): boolean;
  get isIndividual(): boolean;
}
```

```typescript
// verification/domain/entities/verification-request.entity.ts

export class VerificationRequest extends BaseEntity {
  private readonly _id: UUID;
  private readonly _subjectId: UUID;
  private _status: VerificationStatus;
  private _verificationUrl: string | null;
  private _urlExpiresAt: Date | null;
  private _rejectionReasons: RejectionReason[];
  private _canRetry: boolean;

  // Factory methods
  static create(props: CreateRequestProps): VerificationRequest;

  // Domain methods
  start(): void;
  approve(): void;
  reject(reasons: RejectionReason[], canRetry: boolean): void;
  expire(): void;
  cancel(): void;
  regenerateUrl(newUrl: string, expiresAt: Date): void;

  // Invariant checks
  canTransitionTo(newStatus: VerificationStatus): boolean;
  hasActiveUrl(): boolean;

  // Domain events
  private addDomainEvent(event: DomainEvent): void;
}
```

### 4.2 Value Objects

```typescript
// verification/domain/value-objects/subject-type.vo.ts
export enum SubjectType {
  INDIVIDUAL = 'INDIVIDUAL',  // KYC
  COMPANY = 'COMPANY',        // KYB
}

// verification/domain/value-objects/verification-status.vo.ts
export enum VerificationStatus {
  PENDING = 'PENDING',
  IN_PROGRESS = 'IN_PROGRESS',
  APPROVED = 'APPROVED',
  REJECTED = 'REJECTED',
  EXPIRED = 'EXPIRED',
  CANCELLED = 'CANCELLED',
}

// verification/domain/value-objects/rejection-reason.vo.ts
export enum RejectionReason {
  POOR_QUALITY = 'POOR_QUALITY',
  DOCUMENT_EXPIRED = 'DOCUMENT_EXPIRED',
  INVALID_DOCUMENT = 'INVALID_DOCUMENT',
  DOCUMENT_FORGERY = 'DOCUMENT_FORGERY',
  INCOMPLETE_DOCUMENT = 'INCOMPLETE_DOCUMENT',
  DATA_MISMATCH = 'DATA_MISMATCH',
  SELFIE_MISMATCH = 'SELFIE_MISMATCH',
  LIVENESS_FAILED = 'LIVENESS_FAILED',
  SANCTIONS_MATCH = 'SANCTIONS_MATCH',
  PEP_MATCH = 'PEP_MATCH',
  ADVERSE_MEDIA = 'ADVERSE_MEDIA',
  DUPLICATE_ACCOUNT = 'DUPLICATE_ACCOUNT',
  UNSUPPORTED_COUNTRY = 'UNSUPPORTED_COUNTRY',
  UNDERAGE = 'UNDERAGE',
  OTHER = 'OTHER',
}

// verification/domain/value-objects/external-id.vo.ts
export class ExternalId {
  private readonly _value: string;
  private readonly _tenantId: string;
  private readonly _entityId: string;

  private constructor(tenantId: string, entityId: string) {
    this._tenantId = tenantId;
    this._entityId = entityId;
    this._value = `${tenantId}_${entityId}`;
  }

  static create(tenantId: string, entityId: string): ExternalId;
  static fromString(value: string): ExternalId;

  get value(): string;
  get tenantId(): string;
  get entityId(): string;

  equals(other: ExternalId): boolean;
}
```

### 4.3 Domain Events

```typescript
// verification/domain/events/verification-status-changed.event.ts
export class VerificationStatusChangedEvent implements DomainEvent {
  readonly occurredOn: Date;

  constructor(
    readonly verificationRequestId: string,
    readonly previousStatus: VerificationStatus,
    readonly newStatus: VerificationStatus,
    readonly externalId: string,
    readonly subjectType: SubjectType,
  ) {
    this.occurredOn = new Date();
  }
}
```

> **Integration Point**: Domain events like `VerificationStatusChangedEvent` are published to SQS for the notification-service (core-payments team) to trigger emails.

---

## 5. Application Layer Design

### 5.1 Ports (Interfaces)

```typescript
// verification/application/ports/outbound/verification-provider.port.ts

export interface IVerificationProviderPort {
  /**
   * Creates or retrieves verification subject in provider
   * @returns Provider's subject ID (e.g., Sumsub applicantId)
   */
  createOrGetSubject(params: CreateSubjectParams): Promise<string>;

  /**
   * Generates verification URL for user
   */
  generateVerificationUrl(params: GenerateUrlParams): Promise<VerificationUrlResult>;

  /**
   * Gets current verification status from provider
   */
  getVerificationStatus(providerSubjectId: string): Promise<ProviderStatusResult>;

  /**
   * Retrieves subject details (on-demand from provider)
   */
  getSubjectDetails(providerSubjectId: string): Promise<SubjectDetailsResult>;

  /**
   * Validates and processes webhook payload
   */
  processWebhook(payload: string, signature: string): Promise<WebhookProcessResult>;

  /**
   * Generates access token for SDK integration (MVP3)
   */
  generateAccessToken?(params: GenerateTokenParams): Promise<AccessTokenResult>;
}

// Injection token
export const VERIFICATION_PROVIDER_PORT = Symbol('IVerificationProviderPort');
```

```typescript
// verification/application/ports/outbound/verification-request.repository.port.ts

export interface IVerificationRequestRepositoryPort {
  save(request: VerificationRequest): Promise<void>;
  findById(id: UUID): Promise<VerificationRequest | null>;
  findBySubjectId(subjectId: UUID): Promise<VerificationRequest[]>;
  findActiveBySubjectId(subjectId: UUID): Promise<VerificationRequest | null>;
  findByProviderEventId(eventId: string): Promise<VerificationRequest | null>;
}

export const VERIFICATION_REQUEST_REPOSITORY = Symbol('IVerificationRequestRepositoryPort');
```

### 5.2 Use Cases

```typescript
// verification/application/use-cases/initiate-verification.use-case.ts

@Injectable()
export class InitiateVerificationUseCase {
  constructor(
    @Inject(VERIFICATION_PROVIDER_PORT)
    private readonly providerAdapter: IVerificationProviderPort,
    @Inject(VERIFICATION_SUBJECT_REPOSITORY)
    private readonly subjectRepository: IVerificationSubjectRepositoryPort,
    @Inject(VERIFICATION_REQUEST_REPOSITORY)
    private readonly requestRepository: IVerificationRequestRepositoryPort,
    @Inject(VERIFICATION_EVENT_REPOSITORY)
    private readonly eventRepository: IVerificationEventRepositoryPort,
  ) {}

  async execute(dto: InitiateVerificationDto): Promise<VerificationResponseDto> {
    // 1. Build external ID
    // 2. Find or create subject
    // 3. Check for active verification (anti-duplication)
    // 4. Generate verification URL via provider
    // 5. Create verification request
    // 6. Register CREATED event
    // 7. Return response
  }
}
```

```typescript
// verification/application/use-cases/process-webhook.use-case.ts

@Injectable()
export class ProcessWebhookUseCase {
  constructor(
    @Inject(VERIFICATION_PROVIDER_PORT)
    private readonly providerAdapter: IVerificationProviderPort,
    @Inject(PROCESSED_WEBHOOK_REPOSITORY)
    private readonly webhookRepository: IProcessedWebhookRepositoryPort,
    @Inject(VERIFICATION_REQUEST_REPOSITORY)
    private readonly requestRepository: IVerificationRequestRepositoryPort,
    private readonly idempotencyService: WebhookIdempotencyService,
  ) {}

  async execute(payload: string, signature: string): Promise<void> {
    // 1. Validate signature (HMAC-SHA256)
    // 2. Check idempotency (webhookId already processed?)
    // 3. Process webhook via provider adapter
    // 4. Update verification request status
    // 5. Mark webhook as processed
    // 6. Publish domain event (for notification-service)
  }
}
```

---

## 6. Infrastructure Layer Design

### 6.1 Provider Adapter (Sumsub)

```typescript
// verification/infrastructure/providers/sumsub/sumsub.adapter.ts

@Injectable()
export class SumsubAdapter implements IVerificationProviderPort {
  constructor(
    private readonly httpService: HttpService,
    private readonly config: SumsubConfig,
    private readonly statusMapper: SumsubStatusMapper,
    private readonly rejectionMapper: SumsubRejectionMapper,
  ) {}

  async createOrGetSubject(params: CreateSubjectParams): Promise<string> {
    // POST /resources/applicants
  }

  async generateVerificationUrl(params: GenerateUrlParams): Promise<VerificationUrlResult> {
    // POST /resources/sdkIntegrations/levels/{levelName}/websdkLink
  }

  async getVerificationStatus(providerSubjectId: string): Promise<ProviderStatusResult> {
    // GET /resources/applicants/{applicantId}/one
  }

  async processWebhook(payload: string, signature: string): Promise<WebhookProcessResult> {
    // Validate signature (HMAC-SHA256)
    // Map Sumsub event to domain event
  }

  async generateAccessToken(params: GenerateTokenParams): Promise<AccessTokenResult> {
    // POST /resources/accessTokens (MVP3)
  }
}
```

### 6.2 TypeORM Entities

```typescript
// verification/infrastructure/persistence/typeorm/entities/verification-request.orm-entity.ts

@Entity('verification_requests')
@Index('idx_one_active_per_company', ['subjectId'], {
  unique: true,
  where: "status IN ('PENDING', 'IN_PROGRESS')",
})
export class VerificationRequestOrmEntity {
  @PrimaryColumn('uuid')
  id: string;

  @Column('uuid')
  @Index('idx_requests_subject_id')
  subjectId: string;

  @Column({ type: 'varchar', length: 100 })
  levelName: string;

  @Column({ type: 'enum', enum: VerificationStatus })
  @Index('idx_requests_status')
  status: VerificationStatus;

  @Column({ type: 'text', nullable: true })
  verificationUrl: string | null;

  @Column({ type: 'timestamp', nullable: true })
  @Index('idx_requests_url_expires')
  urlExpiresAt: Date | null;

  @Column({ type: 'jsonb', default: [] })
  rejectionReasons: string[];

  @Column({ type: 'boolean', default: false })
  canRetry: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @Column({ type: 'timestamp', nullable: true })
  completedAt: Date | null;
}
```

```typescript
// verification/infrastructure/persistence/typeorm/entities/processed-webhook.orm-entity.ts

@Entity('processed_webhooks')
export class ProcessedWebhookOrmEntity {
  @PrimaryColumn({ type: 'varchar', length: 100 })
  webhookId: string;

  @Column({ type: 'varchar', length: 100 })
  @Index('idx_webhook_external_id')
  externalId: string;

  @Column({ type: 'varchar', length: 50 })
  eventType: string;

  @CreateDateColumn()
  processedAt: Date;
}
```

---

## 7. Module Definitions

### 7.1 Verification Module (Core)

```typescript
// verification/verification.module.ts

@Module({
  imports: [
    TypeOrmModule.forFeature([
      VerificationProviderOrmEntity,
      VerificationSubjectOrmEntity,
      VerificationRequestOrmEntity,
      VerificationEventOrmEntity,
      ProcessedWebhookOrmEntity,
    ]),
    HttpModule,
  ],
  controllers: [
    WebhookController,  // Webhook handling is part of verification module
  ],
  providers: [
    // Use Cases
    InitiateVerificationUseCase,
    GetVerificationStatusUseCase,
    ProcessWebhookUseCase,
    RegenerateVerificationUrlUseCase,

    // Domain Services
    VerificationDomainService,
    WebhookIdempotencyService,

    // Adapters (Provider implementations)
    {
      provide: VERIFICATION_PROVIDER_PORT,
      useClass: SumsubAdapter,
    },

    // Repositories
    {
      provide: VERIFICATION_SUBJECT_REPOSITORY,
      useClass: VerificationSubjectTypeOrmRepository,
    },
    {
      provide: VERIFICATION_REQUEST_REPOSITORY,
      useClass: VerificationRequestTypeOrmRepository,
    },
    {
      provide: VERIFICATION_EVENT_REPOSITORY,
      useClass: VerificationEventTypeOrmRepository,
    },
    {
      provide: PROCESSED_WEBHOOK_REPOSITORY,
      useClass: ProcessedWebhookTypeOrmRepository,
    },

    // Guards
    WebhookSignatureGuard,

    // Mappers
    SumsubStatusMapper,
    SumsubRejectionMapper,
    VerificationMapper,
  ],
  exports: [
    InitiateVerificationUseCase,
    GetVerificationStatusUseCase,
    VERIFICATION_PROVIDER_PORT,
    VERIFICATION_SUBJECT_REPOSITORY,
    VERIFICATION_REQUEST_REPOSITORY,
  ],
})
export class VerificationModule {}
```

### 7.2 KYB Module

```typescript
// kyb/kyb.module.ts

@Module({
  imports: [VerificationModule],
  controllers: [KybController],
  providers: [
    // KYB-specific use cases (facades over verification)
    InitiateKybUseCase,
    GetKybStatusUseCase,

    // Domain service
    KybDomainService,
  ],
  exports: [InitiateKybUseCase, GetKybStatusUseCase],
})
export class KybModule {}
```

### 7.3 KYC Module

```typescript
// kyc/kyc.module.ts

@Module({
  imports: [VerificationModule],
  controllers: [KycController],
  providers: [
    // KYC-specific use cases (facades over verification)
    InitiateKycUseCase,
    GetKycStatusUseCase,

    // Domain service
    KycDomainService,
  ],
  exports: [InitiateKycUseCase, GetKycStatusUseCase],
})
export class KycModule {}
```

### 7.4 App Module (Root)

```typescript
// app.module.ts

@Module({
  imports: [
    // Config
    ConfigModule.forRoot({ isGlobal: true }),

    // Database
    TypeOrmModule.forRootAsync({
      useClass: DatabaseConfigService,
    }),

    // Feature modules
    SharedModule,
    VerificationModule,
    KybModule,
    KycModule,
  ],
})
export class AppModule {}
```

---

## 8. API Contracts

### 8.1 KYB Endpoints

```
POST   /api/v1/kyb/verifications                    # Initiate KYB verification
GET    /api/v1/kyb/verifications/:id                # Get KYB verification status
POST   /api/v1/kyb/verifications/:id/regenerate-url # Regenerate expired link
```

### 8.2 KYC Endpoints

```
POST   /api/v1/kyc/verifications                    # Initiate KYC verification
GET    /api/v1/kyc/verifications/:id                # Get KYC verification status
POST   /api/v1/kyc/verifications/:id/regenerate-url # Regenerate expired link
```

### 8.3 Webhook Endpoints

```
POST   /api/v1/webhooks/sumsub                      # Sumsub webhook receiver
```

---

## 9. Integration with Notification Service

> **Owner**: core-payments team

The compliance-engine does **not** handle email sending directly. Instead, it publishes events to an SQS queue that the notification-service consumes.

### 9.1 Event Publishing (Compliance Engine)

```typescript
// verification/infrastructure/messaging/sqs/verification-event.publisher.ts

@Injectable()
export class VerificationEventPublisher {
  constructor(
    @Inject(SQS_CLIENT)
    private readonly sqsClient: SQSClient,
    private readonly config: MessagingConfig,
  ) {}

  async publishStatusChanged(event: VerificationStatusChangedEvent): Promise<void> {
    const message: VerificationNotificationMessage = {
      type: 'VERIFICATION_STATUS_CHANGED',
      verificationId: event.verificationRequestId,
      externalId: event.externalId,
      subjectType: event.subjectType,
      previousStatus: event.previousStatus,
      newStatus: event.newStatus,
      occurredAt: event.occurredOn.toISOString(),
    };

    await this.sqsClient.send(new SendMessageCommand({
      QueueUrl: this.config.notificationQueueUrl,
      MessageBody: JSON.stringify(message),
    }));
  }
}
```

### 9.2 Message Contract (For notification-service)

```typescript
// libs/contracts/src/compliance.contracts.ts

export interface VerificationNotificationMessage {
  type: 'VERIFICATION_STATUS_CHANGED';
  verificationId: string;
  externalId: string;
  subjectType: 'INDIVIDUAL' | 'COMPANY';
  previousStatus: string;
  newStatus: string;
  occurredAt: string;
}
```

---

## 10. Testing Strategy (TDD)

### 10.1 Test Categories

| Category | Location | Scope | Mocking |
|----------|----------|-------|---------|
| **Unit** | `test/unit/` | Entities, VOs, Use Cases | Full mocking |
| **Integration** | `test/integration/` | Repository + DB, Adapter + HTTP | Test DB, WireMock |
| **E2E** | `test/e2e/` | Full API flow | Test DB, mocked provider |

### 10.2 Test Structure per Use Case

```typescript
// test/unit/verification/application/initiate-verification.use-case.spec.ts

describe('InitiateVerificationUseCase', () => {
  describe('when no existing verification', () => {
    it('should create new subject if not exists');
    it('should generate verification URL');
    it('should create verification request with PENDING status');
    it('should register CREATED event');
  });

  describe('when active verification exists', () => {
    it('should throw ActiveVerificationExistsException');
  });

  describe('when previous verification is REJECTED', () => {
    it('should allow creating new verification');
  });

  describe('when previous verification is EXPIRED', () => {
    it('should allow creating new verification');
  });
});
```

### 10.3 Test Fixtures

```typescript
// test/fixtures/verification.fixtures.ts

export const VerificationFixtures = {
  validCompanySubject: () => ({
    externalId: ExternalId.create('retorna', 'company-001'),
    subjectType: SubjectType.COMPANY,
    countryCode: CountryCode.create('CO'),
  }),

  validIndividualSubject: () => ({
    externalId: ExternalId.create('retorna', 'user-001'),
    subjectType: SubjectType.INDIVIDUAL,
    countryCode: CountryCode.create('CO'),
  }),

  pendingRequest: () => ({
    status: VerificationStatus.PENDING,
    verificationUrl: 'https://sumsub.com/verify/abc123',
    urlExpiresAt: addDays(new Date(), 30),
  }),

  sumsubWebhookApproved: () => ({
    type: 'applicantReviewed',
    applicantId: 'sumsub-app-001',
    reviewResult: { reviewAnswer: 'GREEN' },
    correlationId: 'webhook-001',
  }),
};
```

---

## 11. Configuration & Environment

### 11.1 Environment Variables

```env
# Database
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=compliance_db
DATABASE_USER=app_user
DATABASE_PASSWORD=secret

# Sumsub
SUMSUB_APP_TOKEN=your_app_token
SUMSUB_SECRET_KEY=your_secret_key
SUMSUB_BASE_URL=https://api.sumsub.com
SUMSUB_WEBHOOK_SECRET=webhook_secret

# AWS SQS (for notification-service integration)
AWS_REGION=us-east-1
SQS_NOTIFICATION_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/xxx/verification-notifications

# App
APP_PORT=3000
NODE_ENV=development
LOG_LEVEL=debug
```

---

## 12. Future Capabilities

The compliance-engine is designed to be extensible for additional compliance capabilities:

| Capability | Status | Description |
|------------|--------|-------------|
| **KYB** | MVP | Business verification |
| **KYC** | MVP | Individual verification |
| **AML Screening** | Future | Anti-money laundering checks |
| **Sanctions** | Future | Sanctions list screening |
| **PEP Screening** | Future | Politically exposed persons |
| **Ongoing Monitoring** | Future | Continuous compliance checks |

---

## 13. Key Design Decisions Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Project name** | `compliance-engine` | Reflects broader compliance scope |
| **Architecture** | Hexagonal + DDD | Provider independence, testability |
| **Module structure** | KYB/KYC as facades over verification | Clear API boundaries, shared core |
| **Webhook handling** | Part of verification module | Tightly coupled with verification flow |
| **Provider abstraction** | Port/Adapter pattern | Easy to add Onfido, Jumio, etc. |
| **Email automation** | External (notification-service) | Owned by core-payments team |
| **Status management** | Domain entity with transitions | Encapsulated business rules |
| **Idempotency** | Webhook tracking table | Safe retransmission handling |
| **Anti-duplication** | Unique constraint + API check | Multi-layer protection |
| **Testing** | TDD with 3 layers | Confidence at all levels |
| **Data storage** | References only, no PII | Security, GDPR compliance |
