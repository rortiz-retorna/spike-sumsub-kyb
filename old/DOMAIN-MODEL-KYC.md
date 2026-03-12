# Modelo de Dominio y Contrato Interno - Verificacion de Identidad (KYC/KYB)

> **Version**: 1.0.0
> **Fecha**: 2025-02-24
> **Autor**: Arquitectura de Dominio
> **Estado**: Draft

## Tabla de Contenidos

1. [Introduccion](#1-introduccion)
2. [Principios de Diseno](#2-principios-de-diseno)
3. [Modelo de Dominio](#3-modelo-de-dominio)
4. [Value Objects](#4-value-objects)
5. [Enumeraciones y Estados](#5-enumeraciones-y-estados)
6. [Interfaces y Contratos (Ports)](#6-interfaces-y-contratos-ports)
7. [Eventos de Dominio](#7-eventos-de-dominio)
8. [Excepciones de Dominio](#8-excepciones-de-dominio)
9. [Mapeo Conceptual: Sumsub a Dominio](#9-mapeo-conceptual-sumsub-a-dominio)
10. [Diagramas](#10-diagramas)
11. [Ejemplos de Implementacion](#11-ejemplos-de-implementacion)
12. [Referencias](#12-referencias)

---

## 1. Introduccion

Este documento define el modelo de dominio **provider-agnostic** para la integracion de servicios de verificacion de identidad (KYC - Know Your Customer / KYB - Know Your Business). El modelo esta disenado siguiendo principios de Domain-Driven Design (DDD) y arquitectura hexagonal, permitiendo abstraer cualquier proveedor de verificacion externo (Sumsub, Onfido, Jumio, etc.).

### 1.1 Objetivo

Crear una capa de dominio que:
- Represente los conceptos de negocio de verificacion de identidad
- Sea independiente del proveedor de verificacion utilizado
- Permita cambiar de proveedor sin afectar la logica de negocio
- Use lenguaje ubicuo del dominio de negocio

### 1.2 Alcance

Este modelo cubre:
- Verificacion de identidad de personas (KYC)
- Verificacion de empresas (KYB)
- Gestion de documentos de verificacion
- Estados y transiciones del proceso de verificacion
- Eventos y notificaciones del dominio

---

## 2. Principios de Diseno

### 2.1 Inversion de Dependencias

```
+-------------------+     +------------------+     +-------------------+
|   Aplicacion      |---->|     DOMINIO      |<----|    Adaptador      |
|   (Use Cases)     |     |   (Entidades,    |     |   (Sumsub, etc.)  |
|                   |     |    Puertos)      |     |                   |
+-------------------+     +------------------+     +-------------------+
```

El dominio **NUNCA** depende de implementaciones externas. Los adaptadores implementan los puertos (interfaces) definidos por el dominio.

### 2.2 Lenguaje Ubicuo

| Termino de Negocio | Descripcion |
|-------------------|-------------|
| Sujeto de Verificacion | Persona o empresa que se somete a verificacion |
| Solicitud de Verificacion | Proceso de verificacion iniciado |
| Documento de Identidad | Documento presentado para verificar identidad |
| Resultado de Verificacion | Outcome del proceso de verificacion |
| Nivel de Verificacion | Conjunto de requisitos para un tipo de verificacion |

### 2.3 Reglas de Diseno

1. **Sin terminologia del proveedor**: Nunca usar "Applicant", "Inspection", etc.
2. **Estados genericos**: Los estados deben ser comprensibles sin conocer el proveedor
3. **Extensibilidad**: Facil agregar nuevos tipos de documentos o verificaciones
4. **Inmutabilidad**: Value Objects deben ser inmutables

---

## 3. Modelo de Dominio

### 3.1 Entidades de Dominio

#### 3.1.1 VerificationSubject (Sujeto de Verificacion)

Representa a la persona o empresa que se somete al proceso de verificacion.

```typescript
/**
 * Sujeto de Verificacion
 *
 * Representa la entidad (persona o empresa) que sera verificada.
 * Esta es la entidad raiz del agregado de verificacion.
 *
 * @invariant externalId debe ser unico en el sistema
 * @invariant type determina los campos requeridos
 */
interface VerificationSubject {
  /** Identificador unico interno del dominio */
  id: VerificationSubjectId;

  /** Identificador externo (referencia en nuestro sistema - ej: userId, companyId) */
  externalId: ExternalReferenceId;

  /** Tipo de sujeto: persona natural o empresa */
  type: SubjectType;

  /** Informacion personal (solo para INDIVIDUAL) */
  personalInfo?: PersonalInfo;

  /** Informacion de empresa (solo para COMPANY) */
  companyInfo?: CompanyInfo;

  /** Informacion de contacto */
  contactInfo?: ContactInfo;

  /** Nivel de verificacion requerido */
  verificationLevel: VerificationLevelId;

  /** Historial de verificaciones */
  verificationHistory: VerificationRequest[];

  /** Verificacion activa actual */
  activeVerification?: VerificationRequest;

  /** Metadata adicional */
  metadata: Record<string, unknown>;

  /** Fecha de creacion */
  createdAt: Date;

  /** Fecha de ultima actualizacion */
  updatedAt: Date;
}
```

#### 3.1.2 VerificationRequest (Solicitud de Verificacion)

Representa una solicitud de verificacion especifica.

```typescript
/**
 * Solicitud de Verificacion
 *
 * Representa un proceso de verificacion especifico para un sujeto.
 * Un sujeto puede tener multiples solicitudes a lo largo del tiempo.
 *
 * @invariant Solo puede haber una solicitud activa por sujeto
 * @invariant El estado sigue un flujo definido de transiciones
 */
interface VerificationRequest {
  /** Identificador unico de la solicitud */
  id: VerificationRequestId;

  /** Referencia al sujeto de verificacion */
  subjectId: VerificationSubjectId;

  /** Nivel de verificacion aplicado */
  verificationLevel: VerificationLevel;

  /** Estado actual de la verificacion */
  status: VerificationStatus;

  /** Resultado de la verificacion (cuando esta completada) */
  result?: VerificationResult;

  /** Documentos presentados */
  documents: VerificationDocument[];

  /** Pasos de verificacion requeridos */
  requiredSteps: VerificationStep[];

  /** URL de verificacion (para flujos web/SDK) */
  verificationUrl?: string;

  /** Fecha de expiracion del link de verificacion */
  urlExpiresAt?: Date;

  /** Fecha de inicio */
  startedAt: Date;

  /** Fecha de finalizacion */
  completedAt?: Date;

  /** Fecha de ultima actualizacion */
  updatedAt: Date;
}
```

#### 3.1.3 VerificationDocument (Documento de Verificacion)

Representa un documento presentado para verificacion.

```typescript
/**
 * Documento de Verificacion
 *
 * Representa un documento de identidad o soporte presentado
 * durante el proceso de verificacion.
 *
 * @invariant Los documentos de doble cara requieren ambos lados
 */
interface VerificationDocument {
  /** Identificador unico del documento */
  id: DocumentId;

  /** Tipo de documento */
  type: DocumentType;

  /** Subtipo (cara del documento) */
  side?: DocumentSide;

  /** Pais emisor del documento (ISO 3166-1 alpha-2) */
  issuingCountry: CountryCode;

  /** Numero del documento (si aplica) */
  documentNumber?: string;

  /** Fecha de emision */
  issuedDate?: Date;

  /** Fecha de expiracion */
  expirationDate?: Date;

  /** Estado del documento en la verificacion */
  status: DocumentStatus;

  /** Datos extraidos del documento (OCR) */
  extractedData?: ExtractedDocumentData;

  /** Resultado de validacion del documento */
  validationResult?: DocumentValidationResult;

  /** Fecha de carga */
  uploadedAt: Date;
}
```

#### 3.1.4 VerificationLevel (Nivel de Verificacion)

Define los requisitos para un tipo de verificacion.

```typescript
/**
 * Nivel de Verificacion
 *
 * Define los requisitos y configuracion para un proceso
 * de verificacion especifico.
 */
interface VerificationLevel {
  /** Identificador del nivel */
  id: VerificationLevelId;

  /** Nombre legible del nivel */
  name: string;

  /** Descripcion del nivel */
  description: string;

  /** Tipo de sujeto que aplica */
  subjectType: SubjectType;

  /** Pasos de verificacion requeridos */
  requiredSteps: VerificationStepType[];

  /** Tipos de documentos aceptados */
  acceptedDocumentTypes: DocumentType[];

  /** Paises soportados */
  supportedCountries: CountryCode[];

  /** Tiempo de expiracion del link (segundos) */
  linkExpirationSeconds: number;

  /** Configuracion adicional */
  configuration: Record<string, unknown>;

  /** Estado del nivel */
  isActive: boolean;
}
```

---

## 4. Value Objects

### 4.1 Identificadores

```typescript
/**
 * Identificador de Sujeto de Verificacion
 * Inmutable, generado por el sistema
 */
type VerificationSubjectId = Brand<string, 'VerificationSubjectId'>;

/**
 * Identificador de Solicitud de Verificacion
 * Inmutable, generado por el sistema
 */
type VerificationRequestId = Brand<string, 'VerificationRequestId'>;

/**
 * Identificador de Documento
 * Inmutable, generado por el sistema
 */
type DocumentId = Brand<string, 'DocumentId'>;

/**
 * Identificador de Nivel de Verificacion
 * Referencia a configuracion predefinida
 */
type VerificationLevelId = Brand<string, 'VerificationLevelId'>;

/**
 * Referencia externa (ID en sistema origen)
 * Ej: userId, companyId de nuestra aplicacion
 */
type ExternalReferenceId = Brand<string, 'ExternalReferenceId'>;

/**
 * Codigo de pais ISO 3166-1 alpha-2
 */
type CountryCode = Brand<string, 'CountryCode'>;

// Utility type para branded types
type Brand<T, B> = T & { __brand: B };
```

### 4.2 Informacion Personal

```typescript
/**
 * Informacion Personal
 * Value Object inmutable con datos de persona natural
 */
interface PersonalInfo {
  /** Nombre(s) */
  readonly firstName: string;

  /** Apellido(s) */
  readonly lastName: string;

  /** Segundo nombre (opcional) */
  readonly middleName?: string;

  /** Fecha de nacimiento */
  readonly dateOfBirth?: Date;

  /** Lugar de nacimiento */
  readonly placeOfBirth?: string;

  /** Genero */
  readonly gender?: Gender;

  /** Nacionalidad (ISO 3166-1 alpha-2) */
  readonly nationality?: CountryCode;

  /** Numero de identificacion fiscal */
  readonly taxId?: string;
}
```

### 4.3 Informacion de Empresa

```typescript
/**
 * Informacion de Empresa
 * Value Object inmutable con datos de empresa
 */
interface CompanyInfo {
  /** Nombre legal de la empresa */
  readonly legalName: string;

  /** Nombre comercial (si difiere del legal) */
  readonly tradingName?: string;

  /** Numero de registro/identificacion */
  readonly registrationNumber?: string;

  /** Numero de identificacion fiscal */
  readonly taxId?: string;

  /** Pais de constitucion */
  readonly countryOfIncorporation: CountryCode;

  /** Fecha de constitucion */
  readonly incorporationDate?: Date;

  /** Tipo de empresa */
  readonly companyType?: CompanyType;

  /** Direccion registrada */
  readonly registeredAddress?: Address;

  /** Industria/sector */
  readonly industry?: string;

  /** Sitio web */
  readonly website?: string;
}
```

### 4.4 Informacion de Contacto

```typescript
/**
 * Informacion de Contacto
 * Value Object inmutable
 */
interface ContactInfo {
  /** Email */
  readonly email?: string;

  /** Telefono */
  readonly phone?: string;

  /** Direccion */
  readonly address?: Address;
}

/**
 * Direccion
 * Value Object inmutable
 */
interface Address {
  /** Calle y numero */
  readonly street: string;

  /** Linea adicional */
  readonly streetLine2?: string;

  /** Ciudad */
  readonly city: string;

  /** Estado/Provincia */
  readonly state?: string;

  /** Codigo postal */
  readonly postalCode: string;

  /** Pais (ISO 3166-1 alpha-2) */
  readonly country: CountryCode;
}
```

### 4.5 Datos Extraidos de Documento

```typescript
/**
 * Datos extraidos via OCR del documento
 * Value Object inmutable
 */
interface ExtractedDocumentData {
  /** Nombre completo */
  readonly fullName?: string;

  /** Numero del documento */
  readonly documentNumber?: string;

  /** Fecha de nacimiento */
  readonly dateOfBirth?: Date;

  /** Fecha de expiracion */
  readonly expirationDate?: Date;

  /** Fecha de emision */
  readonly issuedDate?: Date;

  /** Nacionalidad */
  readonly nationality?: CountryCode;

  /** Genero */
  readonly gender?: Gender;

  /** Direccion */
  readonly address?: string;

  /** MRZ (Machine Readable Zone) */
  readonly mrz?: string;

  /** Datos adicionales extraidos */
  readonly additionalData?: Record<string, unknown>;
}
```

---

## 5. Enumeraciones y Estados

### 5.1 Tipo de Sujeto

```typescript
/**
 * Tipo de Sujeto de Verificacion
 */
enum SubjectType {
  /** Persona natural */
  INDIVIDUAL = 'INDIVIDUAL',

  /** Empresa/Organizacion */
  COMPANY = 'COMPANY'
}
```

### 5.2 Estado de Verificacion

```typescript
/**
 * Estado de la Solicitud de Verificacion
 *
 * Flujo de estados:
 *
 *   CREATED --> PENDING --> IN_REVIEW --> APPROVED
 *                  |            |
 *                  |            +--> REJECTED
 *                  |            |
 *                  |            +--> ON_HOLD
 *                  |                    |
 *                  +<-------------------+
 *                  |
 *                  +--> EXPIRED
 *                  |
 *                  +--> CANCELLED
 */
enum VerificationStatus {
  /** Solicitud creada, esperando inicio */
  CREATED = 'CREATED',

  /** Documentos enviados, esperando revision */
  PENDING = 'PENDING',

  /** En proceso de revision */
  IN_REVIEW = 'IN_REVIEW',

  /** En espera de accion adicional */
  ON_HOLD = 'ON_HOLD',

  /** Esperando accion del usuario */
  AWAITING_USER_ACTION = 'AWAITING_USER_ACTION',

  /** Verificacion aprobada */
  APPROVED = 'APPROVED',

  /** Verificacion rechazada */
  REJECTED = 'REJECTED',

  /** Solicitud expirada */
  EXPIRED = 'EXPIRED',

  /** Solicitud cancelada */
  CANCELLED = 'CANCELLED'
}
```

### 5.3 Tipo de Resultado de Verificacion

```typescript
/**
 * Resultado de la Verificacion
 */
enum VerificationOutcome {
  /** Verificacion exitosa */
  APPROVED = 'APPROVED',

  /** Verificacion fallida - puede reintentar */
  REJECTED_RETRY = 'REJECTED_RETRY',

  /** Verificacion fallida - rechazo final */
  REJECTED_FINAL = 'REJECTED_FINAL'
}
```

### 5.4 Tipos de Documento

```typescript
/**
 * Tipos de Documento de Identidad
 * Agnostico al proveedor
 */
enum DocumentType {
  // Documentos de Identidad Principal
  /** Pasaporte */
  PASSPORT = 'PASSPORT',

  /** Documento Nacional de Identidad */
  NATIONAL_ID = 'NATIONAL_ID',

  /** Licencia de Conducir */
  DRIVERS_LICENSE = 'DRIVERS_LICENSE',

  /** Permiso de Residencia */
  RESIDENCE_PERMIT = 'RESIDENCE_PERMIT',

  /** Visa */
  VISA = 'VISA',

  // Documentos de Prueba de Direccion
  /** Factura de Servicios */
  UTILITY_BILL = 'UTILITY_BILL',

  /** Extracto Bancario */
  BANK_STATEMENT = 'BANK_STATEMENT',

  /** Documento Gubernamental */
  GOVERNMENT_LETTER = 'GOVERNMENT_LETTER',

  // Documentos Biometricos
  /** Selfie */
  SELFIE = 'SELFIE',

  /** Video Selfie (Liveness) */
  VIDEO_SELFIE = 'VIDEO_SELFIE',

  // Documentos de Empresa
  /** Certificado de Constitucion */
  INCORPORATION_CERTIFICATE = 'INCORPORATION_CERTIFICATE',

  /** Acta Constitutiva */
  ARTICLES_OF_INCORPORATION = 'ARTICLES_OF_INCORPORATION',

  /** Registro Mercantil */
  COMMERCIAL_REGISTRY = 'COMMERCIAL_REGISTRY',

  /** Certificado de Buena Conducta */
  GOOD_STANDING_CERTIFICATE = 'GOOD_STANDING_CERTIFICATE',

  /** Poder Notarial */
  POWER_OF_ATTORNEY = 'POWER_OF_ATTORNEY',

  /** Registro de Accionistas */
  SHAREHOLDER_REGISTRY = 'SHAREHOLDER_REGISTRY',

  /** Registro de Directores */
  DIRECTORS_REGISTRY = 'DIRECTORS_REGISTRY',

  /** Licencia Regulatoria */
  REGULATORY_LICENSE = 'REGULATORY_LICENSE',

  /** Prueba de Direccion Empresarial */
  BUSINESS_PROOF_OF_ADDRESS = 'BUSINESS_PROOF_OF_ADDRESS',

  // Otros
  /** Documento Generico */
  OTHER = 'OTHER'
}
```

### 5.5 Lado del Documento

```typescript
/**
 * Lado del Documento (para documentos de doble cara)
 */
enum DocumentSide {
  /** Lado frontal */
  FRONT = 'FRONT',

  /** Lado posterior */
  BACK = 'BACK',

  /** Documento de una sola cara */
  SINGLE = 'SINGLE'
}
```

### 5.6 Estado del Documento

```typescript
/**
 * Estado del Documento en la Verificacion
 */
enum DocumentStatus {
  /** Documento subido, pendiente de procesamiento */
  UPLOADED = 'UPLOADED',

  /** En proceso de verificacion */
  PROCESSING = 'PROCESSING',

  /** Documento verificado exitosamente */
  VERIFIED = 'VERIFIED',

  /** Documento rechazado */
  REJECTED = 'REJECTED',

  /** Documento expirado */
  EXPIRED = 'EXPIRED'
}
```

### 5.7 Razon de Rechazo

```typescript
/**
 * Razones de Rechazo
 * Categorias genericas independientes del proveedor
 */
enum RejectionReason {
  // Problemas de Documento
  /** Documento ilegible o de baja calidad */
  POOR_QUALITY = 'POOR_QUALITY',

  /** Documento expirado */
  DOCUMENT_EXPIRED = 'DOCUMENT_EXPIRED',

  /** Documento no valido o no soportado */
  INVALID_DOCUMENT = 'INVALID_DOCUMENT',

  /** Documento alterado o falsificado */
  DOCUMENT_FORGERY = 'DOCUMENT_FORGERY',

  /** Documento de otra persona */
  DOCUMENT_MISMATCH = 'DOCUMENT_MISMATCH',

  /** Falta parte del documento (ej: lado trasero) */
  INCOMPLETE_DOCUMENT = 'INCOMPLETE_DOCUMENT',

  // Problemas de Identidad
  /** Datos no coinciden */
  DATA_MISMATCH = 'DATA_MISMATCH',

  /** Selfie no coincide con documento */
  SELFIE_MISMATCH = 'SELFIE_MISMATCH',

  /** Fallo en verificacion de vida (liveness) */
  LIVENESS_FAILED = 'LIVENESS_FAILED',

  /** Sospecha de identidad falsa */
  FRAUDULENT_IDENTITY = 'FRAUDULENT_IDENTITY',

  // Problemas de Compliance
  /** Encontrado en lista de sanciones */
  SANCTIONS_MATCH = 'SANCTIONS_MATCH',

  /** Persona Politicamente Expuesta */
  PEP_MATCH = 'PEP_MATCH',

  /** Media adversa */
  ADVERSE_MEDIA = 'ADVERSE_MEDIA',

  /** Cuenta duplicada */
  DUPLICATE_ACCOUNT = 'DUPLICATE_ACCOUNT',

  /** Pais no soportado */
  UNSUPPORTED_COUNTRY = 'UNSUPPORTED_COUNTRY',

  /** Menor de edad */
  UNDERAGE = 'UNDERAGE',

  // Otros
  /** Otro motivo */
  OTHER = 'OTHER'
}
```

### 5.8 Pasos de Verificacion

```typescript
/**
 * Tipos de Pasos de Verificacion
 */
enum VerificationStepType {
  /** Verificacion de documento de identidad */
  IDENTITY_DOCUMENT = 'IDENTITY_DOCUMENT',

  /** Verificacion de selfie */
  SELFIE = 'SELFIE',

  /** Verificacion de vida (liveness) */
  LIVENESS = 'LIVENESS',

  /** Prueba de direccion */
  PROOF_OF_ADDRESS = 'PROOF_OF_ADDRESS',

  /** Verificacion de telefono */
  PHONE_VERIFICATION = 'PHONE_VERIFICATION',

  /** Verificacion de email */
  EMAIL_VERIFICATION = 'EMAIL_VERIFICATION',

  /** Screening AML */
  AML_SCREENING = 'AML_SCREENING',

  /** Documentos de empresa */
  COMPANY_DOCUMENTS = 'COMPANY_DOCUMENTS',

  /** Verificacion de beneficiarios finales */
  BENEFICIAL_OWNERS = 'BENEFICIAL_OWNERS',

  /** Video identificacion */
  VIDEO_IDENTIFICATION = 'VIDEO_IDENTIFICATION'
}

/**
 * Estado de un Paso de Verificacion
 */
interface VerificationStep {
  /** Tipo de paso */
  type: VerificationStepType;

  /** Estado del paso */
  status: VerificationStepStatus;

  /** Resultado del paso */
  result?: StepResult;

  /** Fecha de inicio */
  startedAt?: Date;

  /** Fecha de completado */
  completedAt?: Date;
}

enum VerificationStepStatus {
  /** Pendiente de iniciar */
  PENDING = 'PENDING',

  /** En progreso */
  IN_PROGRESS = 'IN_PROGRESS',

  /** Completado exitosamente */
  COMPLETED = 'COMPLETED',

  /** Fallido */
  FAILED = 'FAILED',

  /** Saltado/No requerido */
  SKIPPED = 'SKIPPED'
}

interface StepResult {
  /** Si el paso fue exitoso */
  success: boolean;

  /** Mensaje descriptivo */
  message?: string;

  /** Datos adicionales del resultado */
  data?: Record<string, unknown>;
}
```

### 5.9 Otros Enums

```typescript
/**
 * Genero
 */
enum Gender {
  MALE = 'MALE',
  FEMALE = 'FEMALE',
  OTHER = 'OTHER',
  UNKNOWN = 'UNKNOWN'
}

/**
 * Tipo de Empresa
 */
enum CompanyType {
  /** Sociedad Anonima */
  CORPORATION = 'CORPORATION',

  /** Sociedad de Responsabilidad Limitada */
  LLC = 'LLC',

  /** Sociedad en Comandita */
  PARTNERSHIP = 'PARTNERSHIP',

  /** Empresa Unipersonal */
  SOLE_PROPRIETORSHIP = 'SOLE_PROPRIETORSHIP',

  /** Organizacion sin fines de lucro */
  NON_PROFIT = 'NON_PROFIT',

  /** Fideicomiso */
  TRUST = 'TRUST',

  /** Otro */
  OTHER = 'OTHER'
}
```

---

## 6. Interfaces y Contratos (Ports)

### 6.1 Puerto Principal: VerificationService

```typescript
/**
 * Puerto principal para servicios de verificacion
 *
 * Este es el contrato que deben implementar los adaptadores
 * de proveedores externos (Sumsub, Onfido, etc.)
 */
interface IVerificationService {
  /**
   * Crea un nuevo sujeto de verificacion en el proveedor
   *
   * @param subject - Datos del sujeto a crear
   * @returns Sujeto creado con ID del proveedor
   * @throws VerificationSubjectAlreadyExistsError si ya existe
   * @throws VerificationProviderError si hay error del proveedor
   */
  createSubject(subject: CreateSubjectCommand): Promise<VerificationSubject>;

  /**
   * Obtiene un sujeto de verificacion por su ID externo
   *
   * @param externalId - ID externo (de nuestro sistema)
   * @returns Sujeto si existe, null si no
   */
  getSubjectByExternalId(externalId: ExternalReferenceId): Promise<VerificationSubject | null>;

  /**
   * Inicia un nuevo proceso de verificacion
   *
   * @param request - Datos de la solicitud de verificacion
   * @returns Solicitud creada con URL de verificacion
   * @throws VerificationSubjectNotFoundError si el sujeto no existe
   * @throws VerificationAlreadyInProgressError si ya hay una activa
   */
  initiateVerification(request: InitiateVerificationCommand): Promise<VerificationRequest>;

  /**
   * Obtiene el estado actual de una verificacion
   *
   * @param requestId - ID de la solicitud de verificacion
   * @returns Estado actual de la verificacion
   */
  getVerificationStatus(requestId: VerificationRequestId): Promise<VerificationRequest>;

  /**
   * Obtiene el resultado de una verificacion completada
   *
   * @param requestId - ID de la solicitud de verificacion
   * @returns Resultado detallado de la verificacion
   * @throws VerificationNotCompletedError si aun no esta completa
   */
  getVerificationResult(requestId: VerificationRequestId): Promise<VerificationResult>;

  /**
   * Cancela una verificacion en progreso
   *
   * @param requestId - ID de la solicitud de verificacion
   * @throws VerificationAlreadyCompletedError si ya esta completa
   */
  cancelVerification(requestId: VerificationRequestId): Promise<void>;

  /**
   * Reinicia una verificacion rechazada
   *
   * @param requestId - ID de la solicitud de verificacion
   * @returns Nueva solicitud de verificacion
   * @throws VerificationCannotBeRetriedError si es rechazo final
   */
  retryVerification(requestId: VerificationRequestId): Promise<VerificationRequest>;
}
```

### 6.2 Puerto de URL de Verificacion

```typescript
/**
 * Puerto para generacion de URLs de verificacion (permalinks/SDK)
 */
interface IVerificationUrlService {
  /**
   * Genera una URL para que el usuario complete la verificacion
   *
   * @param command - Datos para generar la URL
   * @returns URL y metadata asociada
   */
  generateVerificationUrl(command: GenerateUrlCommand): Promise<VerificationUrlResult>;

  /**
   * Invalida una URL de verificacion existente
   *
   * @param requestId - ID de la solicitud asociada
   */
  invalidateUrl(requestId: VerificationRequestId): Promise<void>;
}

interface GenerateUrlCommand {
  /** ID del sujeto de verificacion */
  subjectId: VerificationSubjectId;

  /** Nivel de verificacion */
  levelId: VerificationLevelId;

  /** Tiempo de vida en segundos (opcional) */
  ttlSeconds?: number;

  /** URL de redireccion al completar (opcional) */
  redirectUrl?: string;

  /** Idioma de la interfaz (opcional) */
  locale?: string;
}

interface VerificationUrlResult {
  /** URL de verificacion */
  url: string;

  /** ID de la solicitud de verificacion creada */
  requestId: VerificationRequestId;

  /** Fecha de expiracion de la URL */
  expiresAt: Date;
}
```

### 6.3 Puerto de Webhooks

```typescript
/**
 * Puerto para procesamiento de notificaciones del proveedor
 */
interface IVerificationWebhookHandler {
  /**
   * Procesa una notificacion entrante del proveedor
   *
   * @param payload - Payload crudo del webhook
   * @param signature - Firma para validacion
   * @returns Evento de dominio procesado
   * @throws InvalidWebhookSignatureError si la firma es invalida
   */
  processWebhook(payload: string, signature: string): Promise<VerificationEvent>;

  /**
   * Valida la firma de un webhook
   *
   * @param payload - Payload crudo
   * @param signature - Firma a validar
   * @returns true si la firma es valida
   */
  validateSignature(payload: string, signature: string): boolean;
}
```

### 6.4 Puerto de Documentos

```typescript
/**
 * Puerto para gestion de documentos de verificacion
 */
interface IDocumentService {
  /**
   * Obtiene los documentos de una verificacion
   *
   * @param requestId - ID de la solicitud de verificacion
   * @returns Lista de documentos
   */
  getDocuments(requestId: VerificationRequestId): Promise<VerificationDocument[]>;

  /**
   * Obtiene un documento especifico
   *
   * @param documentId - ID del documento
   * @returns Documento con datos extraidos
   */
  getDocument(documentId: DocumentId): Promise<VerificationDocument>;

  /**
   * Obtiene la imagen de un documento
   *
   * @param documentId - ID del documento
   * @returns Datos binarios de la imagen
   */
  getDocumentImage(documentId: DocumentId): Promise<DocumentImage>;
}

interface DocumentImage {
  /** Datos binarios de la imagen */
  data: Buffer;

  /** Tipo MIME */
  mimeType: string;

  /** Nombre del archivo */
  filename: string;
}
```

### 6.5 Puerto de Niveles de Verificacion

```typescript
/**
 * Puerto para gestion de niveles de verificacion
 */
interface IVerificationLevelService {
  /**
   * Obtiene todos los niveles de verificacion disponibles
   *
   * @returns Lista de niveles
   */
  getLevels(): Promise<VerificationLevel[]>;

  /**
   * Obtiene un nivel por su ID
   *
   * @param levelId - ID del nivel
   * @returns Nivel de verificacion
   * @throws VerificationLevelNotFoundError si no existe
   */
  getLevel(levelId: VerificationLevelId): Promise<VerificationLevel>;

  /**
   * Obtiene el nivel apropiado para un pais y tipo de sujeto
   *
   * @param country - Codigo de pais
   * @param subjectType - Tipo de sujeto
   * @returns Nivel de verificacion recomendado
   */
  getLevelForCountry(country: CountryCode, subjectType: SubjectType): Promise<VerificationLevel>;
}
```

### 6.6 DTOs de Comandos

```typescript
/**
 * Comando para crear un sujeto de verificacion
 */
interface CreateSubjectCommand {
  /** ID externo (de nuestro sistema) */
  externalId: ExternalReferenceId;

  /** Tipo de sujeto */
  type: SubjectType;

  /** Nivel de verificacion */
  levelId: VerificationLevelId;

  /** Informacion personal (para INDIVIDUAL) */
  personalInfo?: PersonalInfo;

  /** Informacion de empresa (para COMPANY) */
  companyInfo?: CompanyInfo;

  /** Informacion de contacto */
  contactInfo?: ContactInfo;

  /** Metadata adicional */
  metadata?: Record<string, unknown>;
}

/**
 * Comando para iniciar verificacion
 */
interface InitiateVerificationCommand {
  /** ID del sujeto de verificacion */
  subjectId: VerificationSubjectId;

  /** ID externo (alternativo al subjectId) */
  externalId?: ExternalReferenceId;

  /** Nivel de verificacion (opcional si ya esta definido en sujeto) */
  levelId?: VerificationLevelId;

  /** Tiempo de vida de la URL en segundos */
  urlTtlSeconds?: number;

  /** URL de redireccion post-verificacion */
  redirectUrl?: string;

  /** Idioma de la interfaz */
  locale?: string;
}
```

### 6.7 DTOs de Resultados

```typescript
/**
 * Resultado completo de una verificacion
 */
interface VerificationResult {
  /** ID de la solicitud */
  requestId: VerificationRequestId;

  /** Resultado general */
  outcome: VerificationOutcome;

  /** Puede reintentar (si fue rechazado) */
  canRetry: boolean;

  /** Razones de rechazo (si aplica) */
  rejectionReasons?: RejectionReason[];

  /** Comentario para el usuario */
  userMessage?: string;

  /** Comentario interno */
  internalComment?: string;

  /** Resultados por paso */
  stepResults: VerificationStepResult[];

  /** Datos verificados */
  verifiedData?: VerifiedData;

  /** Resultados de compliance */
  complianceResults?: ComplianceResults;

  /** Fecha de la decision */
  decidedAt: Date;
}

/**
 * Resultado de un paso de verificacion
 */
interface VerificationStepResult {
  /** Tipo de paso */
  stepType: VerificationStepType;

  /** Si paso exitosamente */
  passed: boolean;

  /** Razones de fallo (si aplica) */
  failureReasons?: RejectionReason[];

  /** Datos adicionales */
  data?: Record<string, unknown>;
}

/**
 * Datos verificados extraidos
 */
interface VerifiedData {
  /** Datos personales verificados */
  personalInfo?: PersonalInfo;

  /** Datos de empresa verificados */
  companyInfo?: CompanyInfo;

  /** Direccion verificada */
  address?: Address;

  /** Documentos verificados */
  documents: VerifiedDocument[];
}

interface VerifiedDocument {
  /** Tipo de documento */
  type: DocumentType;

  /** Numero del documento */
  number?: string;

  /** Pais emisor */
  issuingCountry: CountryCode;

  /** Fecha de emision */
  issuedDate?: Date;

  /** Fecha de expiracion */
  expirationDate?: Date;
}

/**
 * Resultados de verificacion de compliance
 */
interface ComplianceResults {
  /** Resultado de screening AML */
  amlScreening?: AmlScreeningResult;

  /** Resultado de verificacion PEP */
  pepCheck?: PepCheckResult;

  /** Resultado de verificacion de sanciones */
  sanctionsCheck?: SanctionsCheckResult;
}

interface AmlScreeningResult {
  /** Si paso el screening */
  passed: boolean;

  /** Coincidencias encontradas */
  matches?: AmlMatch[];
}

interface AmlMatch {
  /** Nombre de la lista */
  listName: string;

  /** Tipo de coincidencia */
  matchType: string;

  /** Porcentaje de coincidencia */
  matchScore: number;

  /** Detalles adicionales */
  details?: Record<string, unknown>;
}

interface PepCheckResult {
  /** Si es PEP */
  isPep: boolean;

  /** Nivel de PEP */
  pepLevel?: string;

  /** Detalles */
  details?: string;
}

interface SanctionsCheckResult {
  /** Si tiene sanciones */
  hasSanctions: boolean;

  /** Listas donde aparece */
  sanctionLists?: string[];
}

/**
 * Resultado de validacion de documento
 */
interface DocumentValidationResult {
  /** Si el documento es valido */
  isValid: boolean;

  /** Si el documento es autentico */
  isAuthentic: boolean;

  /** Si el documento ha expirado */
  isExpired: boolean;

  /** Problemas encontrados */
  issues?: DocumentIssue[];

  /** Nivel de confianza (0-100) */
  confidenceScore?: number;
}

interface DocumentIssue {
  /** Tipo de problema */
  type: RejectionReason;

  /** Descripcion del problema */
  description: string;

  /** Campo afectado */
  field?: string;
}
```

---

## 7. Eventos de Dominio

### 7.1 Definicion de Eventos

```typescript
/**
 * Evento base de verificacion
 */
interface VerificationEvent {
  /** ID unico del evento */
  eventId: string;

  /** Tipo de evento */
  type: VerificationEventType;

  /** ID de la solicitud de verificacion */
  requestId: VerificationRequestId;

  /** ID del sujeto de verificacion */
  subjectId: VerificationSubjectId;

  /** ID externo */
  externalId: ExternalReferenceId;

  /** Timestamp del evento */
  occurredAt: Date;

  /** Payload especifico del evento */
  payload: VerificationEventPayload;
}

/**
 * Tipos de eventos de verificacion
 */
enum VerificationEventType {
  /** Solicitud de verificacion creada */
  VERIFICATION_CREATED = 'VERIFICATION_CREATED',

  /** Verificacion iniciada por el usuario */
  VERIFICATION_STARTED = 'VERIFICATION_STARTED',

  /** Documentos enviados */
  DOCUMENTS_SUBMITTED = 'DOCUMENTS_SUBMITTED',

  /** Verificacion en revision */
  VERIFICATION_IN_REVIEW = 'VERIFICATION_IN_REVIEW',

  /** Verificacion en espera */
  VERIFICATION_ON_HOLD = 'VERIFICATION_ON_HOLD',

  /** Se requiere accion del usuario */
  USER_ACTION_REQUIRED = 'USER_ACTION_REQUIRED',

  /** Verificacion aprobada */
  VERIFICATION_APPROVED = 'VERIFICATION_APPROVED',

  /** Verificacion rechazada */
  VERIFICATION_REJECTED = 'VERIFICATION_REJECTED',

  /** Verificacion expirada */
  VERIFICATION_EXPIRED = 'VERIFICATION_EXPIRED',

  /** Verificacion cancelada */
  VERIFICATION_CANCELLED = 'VERIFICATION_CANCELLED',

  /** Datos del sujeto actualizados */
  SUBJECT_DATA_UPDATED = 'SUBJECT_DATA_UPDATED',

  /** Documento procesado */
  DOCUMENT_PROCESSED = 'DOCUMENT_PROCESSED',

  /** Paso de verificacion completado */
  STEP_COMPLETED = 'STEP_COMPLETED'
}
```

### 7.2 Payloads de Eventos

```typescript
/**
 * Union type de todos los payloads de eventos
 */
type VerificationEventPayload =
  | VerificationCreatedPayload
  | VerificationStartedPayload
  | DocumentsSubmittedPayload
  | VerificationStatusChangedPayload
  | VerificationCompletedPayload
  | SubjectDataUpdatedPayload
  | DocumentProcessedPayload
  | StepCompletedPayload;

/**
 * Payload para evento de verificacion creada
 */
interface VerificationCreatedPayload {
  type: 'VERIFICATION_CREATED';
  levelId: VerificationLevelId;
  verificationUrl?: string;
  urlExpiresAt?: Date;
}

/**
 * Payload para evento de verificacion iniciada
 */
interface VerificationStartedPayload {
  type: 'VERIFICATION_STARTED';
  /** Timestamp cuando el usuario inicio */
  startedAt: Date;
}

/**
 * Payload para evento de documentos enviados
 */
interface DocumentsSubmittedPayload {
  type: 'DOCUMENTS_SUBMITTED';
  /** Documentos enviados */
  documents: Array<{
    documentId: DocumentId;
    documentType: DocumentType;
    side?: DocumentSide;
  }>;
}

/**
 * Payload para cambios de estado
 */
interface VerificationStatusChangedPayload {
  type: 'VERIFICATION_IN_REVIEW' | 'VERIFICATION_ON_HOLD' | 'USER_ACTION_REQUIRED' | 'VERIFICATION_EXPIRED' | 'VERIFICATION_CANCELLED';
  /** Estado anterior */
  previousStatus: VerificationStatus;
  /** Estado nuevo */
  newStatus: VerificationStatus;
  /** Razon del cambio (si aplica) */
  reason?: string;
}

/**
 * Payload para verificacion completada (aprobada o rechazada)
 */
interface VerificationCompletedPayload {
  type: 'VERIFICATION_APPROVED' | 'VERIFICATION_REJECTED';
  /** Resultado de la verificacion */
  outcome: VerificationOutcome;
  /** Puede reintentar */
  canRetry: boolean;
  /** Razones de rechazo */
  rejectionReasons?: RejectionReason[];
  /** Mensaje para usuario */
  userMessage?: string;
}

/**
 * Payload para actualizacion de datos del sujeto
 */
interface SubjectDataUpdatedPayload {
  type: 'SUBJECT_DATA_UPDATED';
  /** Campos actualizados */
  updatedFields: string[];
  /** Datos anteriores (parcial) */
  previousData?: Record<string, unknown>;
  /** Datos nuevos (parcial) */
  newData?: Record<string, unknown>;
}

/**
 * Payload para documento procesado
 */
interface DocumentProcessedPayload {
  type: 'DOCUMENT_PROCESSED';
  /** ID del documento */
  documentId: DocumentId;
  /** Tipo de documento */
  documentType: DocumentType;
  /** Estado del documento */
  status: DocumentStatus;
  /** Datos extraidos */
  extractedData?: ExtractedDocumentData;
}

/**
 * Payload para paso completado
 */
interface StepCompletedPayload {
  type: 'STEP_COMPLETED';
  /** Tipo de paso */
  stepType: VerificationStepType;
  /** Si fue exitoso */
  success: boolean;
  /** Resultado del paso */
  result?: StepResult;
}
```

### 7.3 Event Handler Interface

```typescript
/**
 * Interface para handlers de eventos de verificacion
 */
interface IVerificationEventHandler {
  /**
   * Maneja un evento de verificacion
   *
   * @param event - Evento a procesar
   */
  handle(event: VerificationEvent): Promise<void>;
}

/**
 * Interface para publicar eventos de verificacion
 */
interface IVerificationEventPublisher {
  /**
   * Publica un evento de verificacion
   *
   * @param event - Evento a publicar
   */
  publish(event: VerificationEvent): Promise<void>;

  /**
   * Suscribe un handler a un tipo de evento
   *
   * @param eventType - Tipo de evento
   * @param handler - Handler a ejecutar
   */
  subscribe(eventType: VerificationEventType, handler: IVerificationEventHandler): void;
}
```

---

## 8. Excepciones de Dominio

```typescript
/**
 * Excepcion base de verificacion
 */
abstract class VerificationError extends Error {
  abstract readonly code: string;

  constructor(message: string, public readonly details?: Record<string, unknown>) {
    super(message);
    this.name = this.constructor.name;
  }
}

/**
 * Sujeto de verificacion no encontrado
 */
class VerificationSubjectNotFoundError extends VerificationError {
  readonly code = 'SUBJECT_NOT_FOUND';

  constructor(identifier: string) {
    super(`Verification subject not found: ${identifier}`);
  }
}

/**
 * Sujeto de verificacion ya existe
 */
class VerificationSubjectAlreadyExistsError extends VerificationError {
  readonly code = 'SUBJECT_ALREADY_EXISTS';

  constructor(externalId: string) {
    super(`Verification subject already exists with external ID: ${externalId}`);
  }
}

/**
 * Solicitud de verificacion no encontrada
 */
class VerificationRequestNotFoundError extends VerificationError {
  readonly code = 'REQUEST_NOT_FOUND';

  constructor(requestId: string) {
    super(`Verification request not found: ${requestId}`);
  }
}

/**
 * Ya hay una verificacion en progreso
 */
class VerificationAlreadyInProgressError extends VerificationError {
  readonly code = 'VERIFICATION_IN_PROGRESS';

  constructor(subjectId: string, activeRequestId: string) {
    super(`Verification already in progress for subject ${subjectId}. Active request: ${activeRequestId}`);
  }
}

/**
 * La verificacion ya esta completada
 */
class VerificationAlreadyCompletedError extends VerificationError {
  readonly code = 'VERIFICATION_COMPLETED';

  constructor(requestId: string, status: VerificationStatus) {
    super(`Verification ${requestId} is already completed with status: ${status}`);
  }
}

/**
 * La verificacion aun no esta completada
 */
class VerificationNotCompletedError extends VerificationError {
  readonly code = 'VERIFICATION_NOT_COMPLETED';

  constructor(requestId: string, currentStatus: VerificationStatus) {
    super(`Verification ${requestId} is not completed. Current status: ${currentStatus}`);
  }
}

/**
 * La verificacion no puede ser reintentada
 */
class VerificationCannotBeRetriedError extends VerificationError {
  readonly code = 'CANNOT_RETRY';

  constructor(requestId: string, reason: string) {
    super(`Verification ${requestId} cannot be retried: ${reason}`);
  }
}

/**
 * Nivel de verificacion no encontrado
 */
class VerificationLevelNotFoundError extends VerificationError {
  readonly code = 'LEVEL_NOT_FOUND';

  constructor(levelId: string) {
    super(`Verification level not found: ${levelId}`);
  }
}

/**
 * Nivel de verificacion no soportado para el pais
 */
class UnsupportedCountryError extends VerificationError {
  readonly code = 'UNSUPPORTED_COUNTRY';

  constructor(country: string, levelId: string) {
    super(`Country ${country} is not supported for verification level ${levelId}`);
  }
}

/**
 * Documento no encontrado
 */
class DocumentNotFoundError extends VerificationError {
  readonly code = 'DOCUMENT_NOT_FOUND';

  constructor(documentId: string) {
    super(`Document not found: ${documentId}`);
  }
}

/**
 * Firma de webhook invalida
 */
class InvalidWebhookSignatureError extends VerificationError {
  readonly code = 'INVALID_WEBHOOK_SIGNATURE';

  constructor() {
    super('Invalid webhook signature');
  }
}

/**
 * Error del proveedor de verificacion
 */
class VerificationProviderError extends VerificationError {
  readonly code = 'PROVIDER_ERROR';

  constructor(
    public readonly providerCode: string,
    public readonly providerMessage: string,
    public readonly httpStatus?: number
  ) {
    super(`Verification provider error: ${providerCode} - ${providerMessage}`);
  }
}

/**
 * Datos de verificacion invalidos
 */
class InvalidVerificationDataError extends VerificationError {
  readonly code = 'INVALID_DATA';

  constructor(field: string, reason: string) {
    super(`Invalid verification data for field '${field}': ${reason}`);
  }
}

/**
 * Transicion de estado invalida
 */
class InvalidStatusTransitionError extends VerificationError {
  readonly code = 'INVALID_STATUS_TRANSITION';

  constructor(currentStatus: VerificationStatus, targetStatus: VerificationStatus) {
    super(`Invalid status transition from ${currentStatus} to ${targetStatus}`);
  }
}
```

---

## 9. Mapeo Conceptual: Sumsub a Dominio

Esta seccion documenta la correspondencia entre los conceptos de Sumsub y nuestro modelo de dominio interno.

### 9.1 Entidades

| Concepto Sumsub | Concepto de Dominio | Notas |
|----------------|--------------------|----|
| Applicant | VerificationSubject | Sujeto que se somete a verificacion |
| Applicant ID | VerificationSubjectId | ID interno generado por el proveedor |
| External User ID | ExternalReferenceId | Nuestro ID de usuario/empresa |
| Inspection | VerificationRequest | Proceso de verificacion individual |
| Level | VerificationLevel | Configuracion de requisitos |
| idDoc | VerificationDocument | Documento presentado |

### 9.2 Tipos de Sujeto

| Sumsub Type | Dominio SubjectType |
|-------------|---------------------|
| `individual` | `INDIVIDUAL` |
| `company` | `COMPANY` |

### 9.3 Estados de Verificacion

| Sumsub reviewStatus | Dominio VerificationStatus |
|--------------------|---------------------------|
| `init` | `CREATED` |
| `pending` | `PENDING` |
| `queued` | `IN_REVIEW` |
| `onHold` | `ON_HOLD` |
| `awaitingUser` | `AWAITING_USER_ACTION` |
| `completed` + GREEN | `APPROVED` |
| `completed` + RED | `REJECTED` |
| - | `EXPIRED` |
| - | `CANCELLED` |

### 9.4 Resultados de Verificacion

| Sumsub reviewAnswer | Dominio VerificationOutcome |
|--------------------|----------------------------|
| `GREEN` | `APPROVED` |
| `RED` + `RETRY` | `REJECTED_RETRY` |
| `RED` + `FINAL` | `REJECTED_FINAL` |

### 9.5 Tipos de Documento

| Sumsub idDocType | Dominio DocumentType |
|-----------------|---------------------|
| `PASSPORT` | `PASSPORT` |
| `ID_CARD` | `NATIONAL_ID` |
| `DRIVERS` | `DRIVERS_LICENSE` |
| `RESIDENCE_PERMIT` | `RESIDENCE_PERMIT` |
| `VISA` | `VISA` |
| `UTILITY_BILL` | `UTILITY_BILL` |
| `SELFIE` | `SELFIE` |
| `VIDEO_SELFIE` | `VIDEO_SELFIE` |
| `COMPANY_DOC` | Varios (segun subtype) |

### 9.6 Subtipos de Documento Empresarial

| Sumsub idDocSubType | Dominio DocumentType |
|---------------------|---------------------|
| `INCORPORATION_CERT` | `INCORPORATION_CERTIFICATE` |
| `INCORPORATION_ARTICLES` | `ARTICLES_OF_INCORPORATION` |
| `STATE_REGISTRY` | `COMMERCIAL_REGISTRY` |
| `GOOD_STANDING_CERT` | `GOOD_STANDING_CERTIFICATE` |
| `POWER_OF_ATTORNEY` | `POWER_OF_ATTORNEY` |
| `SHAREHOLDER_REGISTRY` | `SHAREHOLDER_REGISTRY` |
| `DIRECTORS_REGISTRY` | `DIRECTORS_REGISTRY` |
| `REGULATORY_LICENSE` | `REGULATORY_LICENSE` |
| `PROOF_OF_ADDRESS` | `BUSINESS_PROOF_OF_ADDRESS` |

### 9.7 Lados de Documento

| Sumsub idDocSubType | Dominio DocumentSide |
|--------------------|---------------------|
| `FRONT_SIDE` | `FRONT` |
| `BACK_SIDE` | `BACK` |
| (ninguno) | `SINGLE` |

### 9.8 Razones de Rechazo

| Sumsub rejectLabel | Dominio RejectionReason |
|-------------------|------------------------|
| `UNSATISFACTORY_PHOTOS` | `POOR_QUALITY` |
| `DOCUMENT_EXPIRED` | `DOCUMENT_EXPIRED` |
| `NOT_DOCUMENT` | `INVALID_DOCUMENT` |
| `FORGERY` | `DOCUMENT_FORGERY` |
| `INCONSISTENT_PROFILE` | `DOCUMENT_MISMATCH` |
| `INCOMPLETE_DOCUMENT` | `INCOMPLETE_DOCUMENT` |
| `DB_DATA_MISMATCH` | `DATA_MISMATCH` |
| `SELFIE_MISMATCH` | `SELFIE_MISMATCH` |
| `FRAUDULENT_LIVENESS` | `LIVENESS_FAILED` |
| `FRAUDULENT_PATTERNS` | `FRAUDULENT_IDENTITY` |
| `SANCTIONS` | `SANCTIONS_MATCH` |
| `PEP` | `PEP_MATCH` |
| `ADVERSE_MEDIA` | `ADVERSE_MEDIA` |
| `DUPLICATE` | `DUPLICATE_ACCOUNT` |
| `WRONG_USER_REGION` | `UNSUPPORTED_COUNTRY` |
| `AGE_REQUIREMENT_MISMATCH` | `UNDERAGE` |

### 9.9 Tipos de Webhook

| Sumsub Webhook Type | Dominio VerificationEventType |
|--------------------|------------------------------|
| `applicantCreated` | `VERIFICATION_CREATED` |
| `applicantPending` | `DOCUMENTS_SUBMITTED` |
| `applicantReviewed` (GREEN) | `VERIFICATION_APPROVED` |
| `applicantReviewed` (RED) | `VERIFICATION_REJECTED` |
| `applicantOnHold` | `VERIFICATION_ON_HOLD` |
| `applicantAwaitingUser` | `USER_ACTION_REQUIRED` |
| `applicantPersonalInfoChanged` | `SUBJECT_DATA_UPDATED` |
| `applicantReset` | `VERIFICATION_CANCELLED` |
| `applicantDeleted` | `VERIFICATION_CANCELLED` |

---

## 10. Diagramas

### 10.1 Diagrama de Entidades

```
+---------------------------+
|    VerificationSubject    |
+---------------------------+
| - id                      |
| - externalId              |
| - type                    |
| - personalInfo?           |
| - companyInfo?            |
| - contactInfo?            |
| - verificationLevel       |
| - verificationHistory[]   |
| - activeVerification?     |
| - metadata                |
| - createdAt               |
| - updatedAt               |
+---------------------------+
           |
           | 1:N
           v
+---------------------------+
|   VerificationRequest     |
+---------------------------+
| - id                      |
| - subjectId               |
| - verificationLevel       |
| - status                  |
| - result?                 |
| - documents[]             |
| - requiredSteps[]         |
| - verificationUrl?        |
| - urlExpiresAt?           |
| - startedAt               |
| - completedAt?            |
| - updatedAt               |
+---------------------------+
           |
           | 1:N
           v
+---------------------------+
|  VerificationDocument     |
+---------------------------+
| - id                      |
| - type                    |
| - side?                   |
| - issuingCountry          |
| - documentNumber?         |
| - issuedDate?             |
| - expirationDate?         |
| - status                  |
| - extractedData?          |
| - validationResult?       |
| - uploadedAt              |
+---------------------------+
```

### 10.2 Diagrama de Estados de Verificacion

```
                    +----------+
                    | CREATED  |
                    +----+-----+
                         |
           User starts   |
           verification  |
                         v
                    +----------+
    +-------------->| PENDING  |<--------------+
    |               +----+-----+               |
    |                    |                     |
    |    Documents       |                     |
    |    reviewed        |                     |
    |                    v                     |
    |               +-----------+              |
    |               | IN_REVIEW |              |
    |               +-----+-----+              |
    |                     |                    |
    |         +-----------+-----------+        |
    |         |           |           |        |
    |         v           v           v        |
    |   +----------+ +----------+ +--------+   |
    |   | ON_HOLD  | | APPROVED | |REJECTED|   |
    |   +----+-----+ +----------+ +---+----+   |
    |        |                        |        |
    |        |                        |        |
    |        |   RETRY   +------------+        |
    +--------+-----------+                     |
             |                                 |
             |  FINAL                          |
             v                                 |
       +------------+                          |
       | CANCELLED  |                          |
       +------------+                          |
                                               |
       +------------+                          |
       |  EXPIRED   |<-------------------------+
       +------------+      (URL expires)

       +---------------------+
       | AWAITING_USER_ACTION|
       +---------------------+
              ^
              |
       (User action required)
```

### 10.3 Diagrama de Arquitectura Hexagonal

```
                    +----------------------------------+
                    |          APLICACION              |
                    |   (Use Cases / Application       |
                    |         Services)                |
                    +----------------+-----------------+
                                     |
                                     | usa
                                     v
+-------------------+     +----------------------+     +-------------------+
|                   |     |                      |     |                   |
|   REST API        |     |       DOMINIO        |     |    WebSocket      |
|   Controller      |---->|                      |<----|    Handler        |
|                   |     |  - Entidades         |     |                   |
+-------------------+     |  - Value Objects     |     +-------------------+
                          |  - Puertos           |
                          |  - Eventos           |
                          |  - Excepciones       |
                          +----------+-----------+
                                     |
                    define interfaces|
                                     v
          +--------------------------|---------------------------+
          |                          |                           |
+---------v---------+    +-----------v-----------+    +----------v--------+
|                   |    |                       |    |                   |
|  SumsubAdapter    |    |   OnfidoAdapter       |    |   JumioAdapter    |
|                   |    |   (futuro)            |    |   (futuro)        |
|  implements:      |    |                       |    |                   |
|  - IVerification  |    |   implements:         |    |   implements:     |
|    Service        |    |   - IVerification     |    |   - IVerification |
|  - IVerification  |    |     Service           |    |     Service       |
|    UrlService     |    |   - ...               |    |   - ...           |
|  - IWebhook       |    |                       |    |                   |
|    Handler        |    |                       |    |                   |
+-------------------+    +-----------------------+    +-------------------+
          |                          |                           |
          v                          v                           v
+-------------------+    +-----------------------+    +-------------------+
|   Sumsub API      |    |     Onfido API        |    |    Jumio API      |
+-------------------+    +-----------------------+    +-------------------+
```

### 10.4 Diagrama de Flujo de Verificacion

```
+--------+          +----------+         +---------+         +----------+
| Client |          | Backend  |         | Domain  |         | Provider |
|  App   |          |   API    |         | Service |         | (Sumsub) |
+---+----+          +----+-----+         +----+----+         +----+-----+
    |                    |                    |                    |
    | 1. Request         |                    |                    |
    |    Verification    |                    |                    |
    |------------------->|                    |                    |
    |                    |                    |                    |
    |                    | 2. Create Subject  |                    |
    |                    |------------------->|                    |
    |                    |                    |                    |
    |                    |                    | 3. Create          |
    |                    |                    |    Applicant       |
    |                    |                    |------------------->|
    |                    |                    |                    |
    |                    |                    |<-------------------|
    |                    |                    | 4. Applicant ID    |
    |                    |                    |                    |
    |                    |                    | 5. Generate URL    |
    |                    |                    |------------------->|
    |                    |                    |                    |
    |                    |                    |<-------------------|
    |                    |                    | 6. Permalink       |
    |                    |<-------------------|                    |
    |                    | 7. VerificationURL |                    |
    |<-------------------|                    |                    |
    | 8. Verification    |                    |                    |
    |    URL             |                    |                    |
    |                    |                    |                    |
    | 9. User opens URL  |                    |                    |
    |--------------------------------------------+---------------->|
    |                    |                    |                    |
    |                    |                    |   10. User         |
    |                    |                    |       completes    |
    |                    |                    |       verification |
    |                    |                    |                    |
    |                    | 11. Webhook        |                    |
    |                    |<-----------------------------------------|
    |                    |                    |                    |
    |                    | 12. Process        |                    |
    |                    |     Webhook        |                    |
    |                    |------------------->|                    |
    |                    |                    |                    |
    |                    |                    | 13. Emit           |
    |                    |                    |     Domain Event   |
    |                    |<-------------------|                    |
    |                    | 14. Event          |                    |
    |                    |                    |                    |
    | 15. Notification   |                    |                    |
    |<-------------------|                    |                    |
    |                    |                    |                    |
```

---

## 11. Ejemplos de Implementacion

### 11.1 Ejemplo de Adaptador Sumsub (Parcial)

```typescript
// adapters/sumsub/sumsub.adapter.ts

import {
  IVerificationService,
  CreateSubjectCommand,
  VerificationSubject,
  InitiateVerificationCommand,
  VerificationRequest,
  ExternalReferenceId,
  VerificationRequestId,
  VerificationResult,
  SubjectType,
  VerificationStatus,
  VerificationOutcome,
} from '../../domain';

import { SumsubApiClient } from './sumsub-api.client';
import { SumsubMapper } from './sumsub.mapper';

export class SumsubAdapter implements IVerificationService {
  constructor(
    private readonly apiClient: SumsubApiClient,
    private readonly mapper: SumsubMapper,
  ) {}

  async createSubject(command: CreateSubjectCommand): Promise<VerificationSubject> {
    // Mapear de dominio a Sumsub
    const sumsubPayload = this.mapper.toSumsubApplicant(command);

    // Llamar API de Sumsub
    const response = await this.apiClient.createApplicant(sumsubPayload);

    // Mapear respuesta a dominio
    return this.mapper.toVerificationSubject(response, command);
  }

  async getSubjectByExternalId(externalId: ExternalReferenceId): Promise<VerificationSubject | null> {
    try {
      const response = await this.apiClient.getApplicantByExternalId(externalId);
      return this.mapper.toVerificationSubject(response);
    } catch (error) {
      if (error.status === 404) {
        return null;
      }
      throw error;
    }
  }

  async initiateVerification(command: InitiateVerificationCommand): Promise<VerificationRequest> {
    // Generar URL de verificacion
    const urlResponse = await this.apiClient.generateWebSdkLink({
      levelName: command.levelId,
      externalUserId: command.externalId || command.subjectId,
      ttlInSecs: command.urlTtlSeconds,
    });

    return this.mapper.toVerificationRequest(urlResponse, command);
  }

  async getVerificationStatus(requestId: VerificationRequestId): Promise<VerificationRequest> {
    const response = await this.apiClient.getApplicantStatus(requestId);
    return this.mapper.toVerificationRequest(response);
  }

  async getVerificationResult(requestId: VerificationRequestId): Promise<VerificationResult> {
    const response = await this.apiClient.getApplicantReviewResult(requestId);
    return this.mapper.toVerificationResult(response);
  }

  async cancelVerification(requestId: VerificationRequestId): Promise<void> {
    await this.apiClient.resetApplicant(requestId);
  }

  async retryVerification(requestId: VerificationRequestId): Promise<VerificationRequest> {
    await this.apiClient.resetApplicantVerificationSteps(requestId);
    return this.initiateVerification({
      subjectId: requestId,
    });
  }
}
```

### 11.2 Ejemplo de Mapper Sumsub

```typescript
// adapters/sumsub/sumsub.mapper.ts

import {
  CreateSubjectCommand,
  VerificationSubject,
  VerificationRequest,
  VerificationResult,
  VerificationStatus,
  VerificationOutcome,
  SubjectType,
  RejectionReason,
  DocumentType,
  DocumentSide,
} from '../../domain';

export class SumsubMapper {
  /**
   * Mapea comando de dominio a payload de Sumsub
   */
  toSumsubApplicant(command: CreateSubjectCommand): SumsubApplicantPayload {
    return {
      externalUserId: command.externalId,
      type: command.type === SubjectType.COMPANY ? 'company' : 'individual',
      levelName: command.levelId,
      info: command.type === SubjectType.COMPANY
        ? {
            companyInfo: {
              companyName: command.companyInfo?.legalName,
              country: command.companyInfo?.countryOfIncorporation,
              registrationNumber: command.companyInfo?.registrationNumber,
            },
          }
        : {
            firstName: command.personalInfo?.firstName,
            lastName: command.personalInfo?.lastName,
            dob: command.personalInfo?.dateOfBirth?.toISOString().split('T')[0],
            country: command.personalInfo?.nationality,
          },
      email: command.contactInfo?.email,
      phone: command.contactInfo?.phone,
    };
  }

  /**
   * Mapea estado de Sumsub a estado de dominio
   */
  toVerificationStatus(sumsubStatus: string, reviewAnswer?: string): VerificationStatus {
    const statusMap: Record<string, VerificationStatus> = {
      init: VerificationStatus.CREATED,
      pending: VerificationStatus.PENDING,
      queued: VerificationStatus.IN_REVIEW,
      onHold: VerificationStatus.ON_HOLD,
      awaitingUser: VerificationStatus.AWAITING_USER_ACTION,
    };

    if (sumsubStatus === 'completed') {
      return reviewAnswer === 'GREEN'
        ? VerificationStatus.APPROVED
        : VerificationStatus.REJECTED;
    }

    return statusMap[sumsubStatus] || VerificationStatus.PENDING;
  }

  /**
   * Mapea resultado de Sumsub a resultado de dominio
   */
  toVerificationOutcome(reviewAnswer: string, rejectType?: string): VerificationOutcome {
    if (reviewAnswer === 'GREEN') {
      return VerificationOutcome.APPROVED;
    }
    return rejectType === 'FINAL'
      ? VerificationOutcome.REJECTED_FINAL
      : VerificationOutcome.REJECTED_RETRY;
  }

  /**
   * Mapea labels de rechazo de Sumsub a razones de dominio
   */
  toRejectionReasons(rejectLabels: string[]): RejectionReason[] {
    const labelMap: Record<string, RejectionReason> = {
      UNSATISFACTORY_PHOTOS: RejectionReason.POOR_QUALITY,
      DOCUMENT_EXPIRED: RejectionReason.DOCUMENT_EXPIRED,
      NOT_DOCUMENT: RejectionReason.INVALID_DOCUMENT,
      FORGERY: RejectionReason.DOCUMENT_FORGERY,
      INCONSISTENT_PROFILE: RejectionReason.DOCUMENT_MISMATCH,
      INCOMPLETE_DOCUMENT: RejectionReason.INCOMPLETE_DOCUMENT,
      DB_DATA_MISMATCH: RejectionReason.DATA_MISMATCH,
      SELFIE_MISMATCH: RejectionReason.SELFIE_MISMATCH,
      FRAUDULENT_LIVENESS: RejectionReason.LIVENESS_FAILED,
      FRAUDULENT_PATTERNS: RejectionReason.FRAUDULENT_IDENTITY,
      SANCTIONS: RejectionReason.SANCTIONS_MATCH,
      PEP: RejectionReason.PEP_MATCH,
      ADVERSE_MEDIA: RejectionReason.ADVERSE_MEDIA,
      DUPLICATE: RejectionReason.DUPLICATE_ACCOUNT,
      WRONG_USER_REGION: RejectionReason.UNSUPPORTED_COUNTRY,
      AGE_REQUIREMENT_MISMATCH: RejectionReason.UNDERAGE,
    };

    return rejectLabels.map(label => labelMap[label] || RejectionReason.OTHER);
  }

  /**
   * Mapea tipo de documento de Sumsub a dominio
   */
  toDocumentType(idDocType: string): DocumentType {
    const typeMap: Record<string, DocumentType> = {
      PASSPORT: DocumentType.PASSPORT,
      ID_CARD: DocumentType.NATIONAL_ID,
      DRIVERS: DocumentType.DRIVERS_LICENSE,
      RESIDENCE_PERMIT: DocumentType.RESIDENCE_PERMIT,
      VISA: DocumentType.VISA,
      UTILITY_BILL: DocumentType.UTILITY_BILL,
      SELFIE: DocumentType.SELFIE,
      VIDEO_SELFIE: DocumentType.VIDEO_SELFIE,
    };

    return typeMap[idDocType] || DocumentType.OTHER;
  }

  /**
   * Mapea lado de documento de Sumsub a dominio
   */
  toDocumentSide(idDocSubType?: string): DocumentSide {
    if (!idDocSubType) return DocumentSide.SINGLE;

    const sideMap: Record<string, DocumentSide> = {
      FRONT_SIDE: DocumentSide.FRONT,
      BACK_SIDE: DocumentSide.BACK,
    };

    return sideMap[idDocSubType] || DocumentSide.SINGLE;
  }
}

// Tipos internos de Sumsub (no exportados al dominio)
interface SumsubApplicantPayload {
  externalUserId: string;
  type: 'individual' | 'company';
  levelName: string;
  info: Record<string, unknown>;
  email?: string;
  phone?: string;
}
```

### 11.3 Ejemplo de Webhook Handler

```typescript
// adapters/sumsub/sumsub-webhook.handler.ts

import {
  IVerificationWebhookHandler,
  VerificationEvent,
  VerificationEventType,
  InvalidWebhookSignatureError,
} from '../../domain';

import { SumsubMapper } from './sumsub.mapper';
import * as crypto from 'crypto';

export class SumsubWebhookHandler implements IVerificationWebhookHandler {
  constructor(
    private readonly secretKey: string,
    private readonly mapper: SumsubMapper,
  ) {}

  validateSignature(payload: string, signature: string): boolean {
    const expectedSignature = crypto
      .createHmac('sha256', this.secretKey)
      .update(payload)
      .digest('hex');

    return signature === expectedSignature;
  }

  async processWebhook(payload: string, signature: string): Promise<VerificationEvent> {
    if (!this.validateSignature(payload, signature)) {
      throw new InvalidWebhookSignatureError();
    }

    const data = JSON.parse(payload);

    return this.mapWebhookToEvent(data);
  }

  private mapWebhookToEvent(data: SumsubWebhookPayload): VerificationEvent {
    const eventType = this.mapWebhookType(data.type, data.reviewResult?.reviewAnswer);

    return {
      eventId: data.correlationId,
      type: eventType,
      requestId: data.applicantId as any,
      subjectId: data.applicantId as any,
      externalId: data.externalUserId as any,
      occurredAt: new Date(data.createdAtMs),
      payload: this.buildEventPayload(eventType, data),
    };
  }

  private mapWebhookType(
    sumsubType: string,
    reviewAnswer?: string,
  ): VerificationEventType {
    const typeMap: Record<string, VerificationEventType> = {
      applicantCreated: VerificationEventType.VERIFICATION_CREATED,
      applicantPending: VerificationEventType.DOCUMENTS_SUBMITTED,
      applicantOnHold: VerificationEventType.VERIFICATION_ON_HOLD,
      applicantAwaitingUser: VerificationEventType.USER_ACTION_REQUIRED,
      applicantPersonalInfoChanged: VerificationEventType.SUBJECT_DATA_UPDATED,
      applicantReset: VerificationEventType.VERIFICATION_CANCELLED,
      applicantDeleted: VerificationEventType.VERIFICATION_CANCELLED,
    };

    if (sumsubType === 'applicantReviewed') {
      return reviewAnswer === 'GREEN'
        ? VerificationEventType.VERIFICATION_APPROVED
        : VerificationEventType.VERIFICATION_REJECTED;
    }

    return typeMap[sumsubType] || VerificationEventType.VERIFICATION_CREATED;
  }

  private buildEventPayload(
    eventType: VerificationEventType,
    data: SumsubWebhookPayload,
  ): any {
    // Construir payload especifico segun el tipo de evento
    switch (eventType) {
      case VerificationEventType.VERIFICATION_APPROVED:
      case VerificationEventType.VERIFICATION_REJECTED:
        return {
          type: eventType,
          outcome: this.mapper.toVerificationOutcome(
            data.reviewResult?.reviewAnswer || '',
            data.reviewResult?.reviewRejectType,
          ),
          canRetry: data.reviewResult?.reviewRejectType !== 'FINAL',
          rejectionReasons: data.reviewResult?.rejectLabels
            ? this.mapper.toRejectionReasons(data.reviewResult.rejectLabels)
            : undefined,
          userMessage: data.reviewResult?.moderationComment,
        };

      default:
        return {
          type: eventType,
        };
    }
  }
}

interface SumsubWebhookPayload {
  applicantId: string;
  inspectionId: string;
  correlationId: string;
  externalUserId: string;
  type: string;
  reviewStatus: string;
  createdAtMs: string;
  reviewResult?: {
    reviewAnswer?: string;
    rejectLabels?: string[];
    reviewRejectType?: string;
    moderationComment?: string;
  };
}
```

---

## 12. Referencias

### 12.1 Documentacion Oficial de Sumsub

- [Documentacion Principal](https://docs.sumsub.com/) - Portal de documentacion de Sumsub
- [Introduccion a la API](https://docs.sumsub.com/reference/about-sumsub-api) - Conceptos basicos de la API
- [Primeros pasos con API](https://docs.sumsub.com/reference/get-started-with-api) - Guia de inicio
- [Agregar documentos de verificacion](https://docs.sumsub.com/reference/add-verification-documents) - Tipos de documentos soportados
- [Webhooks de verificacion de usuarios](https://docs.sumsub.com/docs/user-verification-webhooks) - Tipos de webhooks y payloads
- [Recibir resultados de verificacion](https://docs.sumsub.com/docs/receive-verification-results) - Estructura de resultados
- [Razones de rechazo](https://docs.sumsub.com/reference/rejected) - Lista completa de reject labels
- [Sobre verificacion de usuarios](https://docs.sumsub.com/docs/user-verification) - Tipos de verificacion disponibles
- [Introduccion a WebSDK](https://docs.sumsub.com/docs/about-web-sdk) - Integracion via SDK web
- [Introduccion a MobileSDK](https://docs.sumsub.com/docs/about-mobile-sdk) - Integracion via SDK movil

### 12.2 Recursos de Arquitectura

- Domain-Driven Design (Eric Evans)
- Clean Architecture (Robert C. Martin)
- Hexagonal Architecture (Alistair Cockburn)
- Implementing Domain-Driven Design (Vaughn Vernon)

### 12.3 Especificaciones Relacionadas

- ISO 3166-1 - Codigos de paises
- ISO 8601 - Formato de fechas

---

## Historial de Cambios

| Version | Fecha | Descripcion | Autor |
|---------|-------|-------------|-------|
| 1.0.0 | 2025-02-24 | Version inicial del documento | Arquitectura |

---

## Checklist de Validacion

- [x] Ningun modelo de dominio menciona "Sumsub" o "Applicant"
- [x] Los contratos usan solo tipos de dominio
- [x] Las entidades tienen validaciones de negocio documentadas
- [x] Los estados son comprensibles sin conocer el proveedor
- [x] Se pueden implementar adaptadores para otros proveedores
- [x] La documentacion incluye diagramas claros
- [x] Se incluye mapeo conceptual Sumsub -> Dominio
- [x] Se incluyen ejemplos de implementacion
- [x] Referencias a documentacion oficial de Sumsub
