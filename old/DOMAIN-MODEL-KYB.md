# Modelo de Dominio y Contrato Interno - Verificacion de Empresas (KYB)

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

Este documento define el modelo de dominio **provider-agnostic** para la integracion de servicios de verificacion de empresas (KYB - Know Your Business). El modelo esta disenado siguiendo principios de Domain-Driven Design (DDD) y arquitectura hexagonal, permitiendo abstraer cualquier proveedor de verificacion externo (Sumsub, Onfido, Jumio, etc.).

### 1.1 Objetivo

Crear una capa de dominio que:
- Represente los conceptos de negocio de verificacion de empresas
- Sea independiente del proveedor de verificacion utilizado
- Permita cambiar de proveedor sin afectar la logica de negocio
- **Rastree el proveedor actual** para auditorias y migraciones
- Use lenguaje ubicuo del dominio de negocio

### 1.2 Alcance

Este modelo cubre exclusivamente **KYB (Know Your Business)**:
- Verificacion de datos de la empresa
- Verificacion de documentos corporativos
- Verificacion de estructura de propiedad (UBOs - Ultimate Beneficial Owners)
- Verificacion de representantes legales
- Screening AML/PEP de la empresa y sus beneficiarios
- Estados y transiciones del proceso de verificacion
- Eventos y notificaciones del dominio

### 1.3 Fuera de Alcance

- Verificacion de personas naturales independientes (KYC puro)
- Verificacion de direcciones personales sin contexto empresarial

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

### 2.2 Lenguaje Ubicuo (KYB)

| Termino de Negocio | Descripcion |
|-------------------|-------------|
| Empresa | Entidad legal que se somete a verificacion KYB |
| Solicitud de Verificacion | Proceso de verificacion KYB iniciado |
| Documento Corporativo | Documento legal de la empresa |
| Beneficiario Final (UBO) | Persona con control/propiedad significativa de la empresa |
| Representante Legal | Persona autorizada para actuar en nombre de la empresa |
| Proveedor de Verificacion | Servicio externo que ejecuta la verificacion (Sumsub, Onfido, etc.) |
| Nivel de Verificacion | Conjunto de requisitos para un tipo de verificacion |

### 2.3 Reglas de Diseno

1. **Sin terminologia del proveedor**: Nunca usar "Applicant", "Inspection", etc.
2. **Estados genericos**: Los estados deben ser comprensibles sin conocer el proveedor
3. **Extensibilidad**: Facil agregar nuevos tipos de documentos o verificaciones
4. **Inmutabilidad**: Value Objects deben ser inmutables
5. **Trazabilidad de proveedor**: Siempre registrar que proveedor proceso la verificacion

---

## 3. Modelo de Dominio

### 3.1 Entidades de Dominio

#### 3.1.1 BusinessVerificationSubject (Empresa a Verificar)

Representa a la empresa que se somete al proceso de verificacion KYB.

```typescript
/**
 * Empresa sujeta a Verificacion KYB
 *
 * Representa la entidad legal/empresa que sera verificada.
 * Esta es la entidad raiz del agregado de verificacion KYB.
 *
 * @invariant externalId debe ser unico en el sistema
 * @invariant Debe tener al menos un representante legal
 */
interface BusinessVerificationSubject {
  /** Identificador unico interno del dominio */
  id: BusinessSubjectId;

  /** Identificador externo (referencia en nuestro sistema - ej: companyId, merchantId) */
  externalId: ExternalReferenceId;

  /** Proveedor de verificacion actual */
  provider: VerificationProvider;

  /** ID asignado por el proveedor externo (para referencias cruzadas) */
  providerSubjectId?: string;

  /** Informacion de la empresa */
  companyInfo: CompanyInfo;

  /** Representantes legales de la empresa */
  legalRepresentatives: LegalRepresentative[];

  /** Beneficiarios finales (UBOs) */
  beneficialOwners: BeneficialOwner[];

  /** Informacion de contacto de la empresa */
  contactInfo: BusinessContactInfo;

  /** Nivel de verificacion requerido */
  verificationLevelId: VerificationLevelId;

  /** Historial de verificaciones */
  verificationHistory: BusinessVerificationRequest[];

  /** Verificacion activa actual */
  activeVerification?: BusinessVerificationRequest;

  /** Metadata adicional */
  metadata: Record<string, unknown>;

  /** Fecha de creacion */
  createdAt: Date;

  /** Fecha de ultima actualizacion */
  updatedAt: Date;
}
```

#### 3.1.2 BusinessVerificationRequest (Solicitud de Verificacion KYB)

Representa una solicitud de verificacion especifica para una empresa.

```typescript
/**
 * Solicitud de Verificacion KYB
 *
 * Representa un proceso de verificacion especifico para una empresa.
 * Una empresa puede tener multiples solicitudes a lo largo del tiempo
 * (re-verificaciones, cambios de proveedor, etc.)
 *
 * @invariant Solo puede haber una solicitud activa por empresa
 * @invariant El estado sigue un flujo definido de transiciones
 */
interface BusinessVerificationRequest {
  /** Identificador unico de la solicitud */
  id: VerificationRequestId;

  /** Referencia a la empresa */
  subjectId: BusinessSubjectId;

  /** Proveedor que procesa esta verificacion */
  provider: VerificationProvider;

  /** ID de la solicitud en el proveedor externo */
  providerRequestId?: string;

  /** Nivel de verificacion aplicado */
  verificationLevel: VerificationLevel;

  /** Estado actual de la verificacion */
  status: VerificationStatus;

  /** Resultado de la verificacion (cuando esta completada) */
  result?: BusinessVerificationResult;

  /** Documentos corporativos presentados */
  documents: CorporateDocument[];

  /** Estado de verificacion de representantes legales */
  representativeVerifications: RepresentativeVerificationStatus[];

  /** Estado de verificacion de UBOs */
  uboVerifications: UboVerificationStatus[];

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

#### 3.1.3 LegalRepresentative (Representante Legal)

Persona autorizada para actuar en nombre de la empresa.

```typescript
/**
 * Representante Legal
 *
 * Persona que tiene autoridad legal para actuar en nombre de la empresa.
 * Puede ser director, CEO, apoderado, etc.
 *
 * @invariant Debe tener documento de identidad valido
 */
interface LegalRepresentative {
  /** Identificador unico */
  id: RepresentativeId;

  /** Informacion personal */
  personalInfo: PersonalInfo;

  /** Rol/cargo en la empresa */
  role: RepresentativeRole;

  /** Titulo del cargo */
  jobTitle?: string;

  /** Informacion de contacto */
  contactInfo?: ContactInfo;

  /** Fecha de nombramiento */
  appointmentDate?: Date;

  /** Es el representante principal */
  isPrimary: boolean;

  /** Estado de verificacion individual */
  verificationStatus: IndividualVerificationStatus;

  /** Documentos de identidad */
  identityDocuments: IdentityDocument[];
}

/**
 * Roles de representante legal
 */
enum RepresentativeRole {
  /** Director / Miembro del consejo */
  DIRECTOR = 'DIRECTOR',

  /** CEO / Director General */
  CEO = 'CEO',

  /** CFO / Director Financiero */
  CFO = 'CFO',

  /** Secretario corporativo */
  CORPORATE_SECRETARY = 'CORPORATE_SECRETARY',

  /** Apoderado / Con poder notarial */
  AUTHORIZED_SIGNATORY = 'AUTHORIZED_SIGNATORY',

  /** Representante legal general */
  LEGAL_REPRESENTATIVE = 'LEGAL_REPRESENTATIVE',

  /** Otro */
  OTHER = 'OTHER'
}
```

#### 3.1.4 BeneficialOwner (Beneficiario Final - UBO)

Persona con control o propiedad significativa de la empresa.

```typescript
/**
 * Beneficiario Final (Ultimate Beneficial Owner - UBO)
 *
 * Persona natural que posee o controla directa/indirectamente
 * un porcentaje significativo de la empresa (tipicamente >= 25%).
 *
 * @invariant percentageOwned debe ser >= 0 y <= 100
 * @invariant Debe tener documento de identidad valido
 */
interface BeneficialOwner {
  /** Identificador unico */
  id: BeneficialOwnerId;

  /** Informacion personal */
  personalInfo: PersonalInfo;

  /** Porcentaje de propiedad directa */
  directOwnershipPercentage: number;

  /** Porcentaje de propiedad indirecta */
  indirectOwnershipPercentage?: number;

  /** Porcentaje total de propiedad */
  totalOwnershipPercentage: number;

  /** Tipo de control (propiedad, votacion, otro) */
  controlType: ControlType;

  /** Descripcion de la cadena de propiedad (si es indirecta) */
  ownershipChainDescription?: string;

  /** Nacionalidad */
  nationality: CountryCode;

  /** Pais de residencia */
  countryOfResidence: CountryCode;

  /** Es PEP (Persona Politicamente Expuesta) */
  isPep: boolean;

  /** Detalles de PEP si aplica */
  pepDetails?: PepDetails;

  /** Estado de verificacion individual */
  verificationStatus: IndividualVerificationStatus;

  /** Documentos de identidad */
  identityDocuments: IdentityDocument[];

  /** Informacion de contacto */
  contactInfo?: ContactInfo;
}

/**
 * Tipo de control sobre la empresa
 */
enum ControlType {
  /** Control por propiedad de acciones */
  OWNERSHIP = 'OWNERSHIP',

  /** Control por derechos de voto */
  VOTING_RIGHTS = 'VOTING_RIGHTS',

  /** Control por otros medios */
  OTHER_MEANS = 'OTHER_MEANS',

  /** Control por estructura de fideicomiso */
  TRUST_BENEFICIARY = 'TRUST_BENEFICIARY'
}

/**
 * Detalles de Persona Politicamente Expuesta
 */
interface PepDetails {
  /** Cargo o posicion politica */
  position: string;

  /** Pais del cargo */
  country: CountryCode;

  /** Fecha de inicio del cargo */
  startDate?: Date;

  /** Fecha de fin del cargo (si ya no es PEP activo) */
  endDate?: Date;

  /** Relacion (si es familiar de PEP) */
  relationship?: PepRelationship;
}

enum PepRelationship {
  /** Es el PEP directamente */
  SELF = 'SELF',

  /** Familiar cercano */
  CLOSE_FAMILY = 'CLOSE_FAMILY',

  /** Asociado cercano */
  CLOSE_ASSOCIATE = 'CLOSE_ASSOCIATE'
}
```

#### 3.1.5 CorporateDocument (Documento Corporativo)

Documento legal de la empresa presentado para verificacion.

```typescript
/**
 * Documento Corporativo
 *
 * Documento legal de la empresa presentado durante
 * el proceso de verificacion KYB.
 */
interface CorporateDocument {
  /** Identificador unico del documento */
  id: DocumentId;

  /** Tipo de documento corporativo */
  type: CorporateDocumentType;

  /** Pais de emision (ISO 3166-1 alpha-2) */
  issuingCountry: CountryCode;

  /** Entidad emisora */
  issuingAuthority?: string;

  /** Numero de documento/registro (si aplica) */
  documentNumber?: string;

  /** Fecha de emision */
  issuedDate?: Date;

  /** Fecha de expiracion (si aplica) */
  expirationDate?: Date;

  /** Estado del documento en la verificacion */
  status: DocumentStatus;

  /** Datos extraidos del documento (OCR) */
  extractedData?: ExtractedCorporateData;

  /** Resultado de validacion del documento */
  validationResult?: DocumentValidationResult;

  /** Fecha de carga */
  uploadedAt: Date;
}

/**
 * Tipos de Documento Corporativo
 */
enum CorporateDocumentType {
  // Documentos de Constitucion
  /** Certificado de Constitucion / Incorporation Certificate */
  INCORPORATION_CERTIFICATE = 'INCORPORATION_CERTIFICATE',

  /** Acta Constitutiva / Articles of Incorporation */
  ARTICLES_OF_INCORPORATION = 'ARTICLES_OF_INCORPORATION',

  /** Estatutos Sociales / Bylaws */
  BYLAWS = 'BYLAWS',

  /** Escritura de Constitucion */
  DEED_OF_INCORPORATION = 'DEED_OF_INCORPORATION',

  // Documentos de Registro
  /** Extracto del Registro Mercantil / Commercial Registry Extract */
  COMMERCIAL_REGISTRY_EXTRACT = 'COMMERCIAL_REGISTRY_EXTRACT',

  /** Certificado de Existencia / Good Standing Certificate */
  GOOD_STANDING_CERTIFICATE = 'GOOD_STANDING_CERTIFICATE',

  /** Certificado de Vigencia */
  CERTIFICATE_OF_INCUMBENCY = 'CERTIFICATE_OF_INCUMBENCY',

  // Documentos Fiscales
  /** Certificado de Identificacion Fiscal / Tax ID Certificate */
  TAX_ID_CERTIFICATE = 'TAX_ID_CERTIFICATE',

  /** Declaracion de Impuestos */
  TAX_RETURN = 'TAX_RETURN',

  // Documentos de Estructura
  /** Registro de Accionistas / Shareholder Registry */
  SHAREHOLDER_REGISTRY = 'SHAREHOLDER_REGISTRY',

  /** Registro de Directores / Directors Registry */
  DIRECTORS_REGISTRY = 'DIRECTORS_REGISTRY',

  /** Estructura de Propiedad / Ownership Structure */
  OWNERSHIP_STRUCTURE_CHART = 'OWNERSHIP_STRUCTURE_CHART',

  /** Declaracion de Beneficiarios Finales / UBO Declaration */
  UBO_DECLARATION = 'UBO_DECLARATION',

  // Documentos de Autorizacion
  /** Poder Notarial / Power of Attorney */
  POWER_OF_ATTORNEY = 'POWER_OF_ATTORNEY',

  /** Acta de Asamblea / Board Resolution */
  BOARD_RESOLUTION = 'BOARD_RESOLUTION',

  /** Acta de Junta de Accionistas */
  SHAREHOLDER_RESOLUTION = 'SHAREHOLDER_RESOLUTION',

  // Documentos Regulatorios
  /** Licencia Regulatoria / Business License */
  BUSINESS_LICENSE = 'BUSINESS_LICENSE',

  /** Licencia Especifica del Sector */
  INDUSTRY_LICENSE = 'INDUSTRY_LICENSE',

  /** Autorizacion de Operacion */
  OPERATING_PERMIT = 'OPERATING_PERMIT',

  // Documentos de Direccion
  /** Prueba de Direccion Empresarial */
  BUSINESS_PROOF_OF_ADDRESS = 'BUSINESS_PROOF_OF_ADDRESS',

  /** Contrato de Arrendamiento */
  LEASE_AGREEMENT = 'LEASE_AGREEMENT',

  /** Factura de Servicios */
  UTILITY_BILL = 'UTILITY_BILL',

  // Documentos Financieros
  /** Estados Financieros Auditados */
  AUDITED_FINANCIAL_STATEMENTS = 'AUDITED_FINANCIAL_STATEMENTS',

  /** Extracto Bancario Empresarial */
  BUSINESS_BANK_STATEMENT = 'BUSINESS_BANK_STATEMENT',

  // Otros
  /** Otro documento */
  OTHER = 'OTHER'
}
```

#### 3.1.6 VerificationLevel (Nivel de Verificacion KYB)

Define los requisitos para un tipo de verificacion KYB.

```typescript
/**
 * Nivel de Verificacion KYB
 *
 * Define los requisitos y configuracion para un proceso
 * de verificacion KYB especifico.
 */
interface VerificationLevel {
  /** Identificador del nivel */
  id: VerificationLevelId;

  /** Nombre legible del nivel */
  name: string;

  /** Descripcion del nivel */
  description: string;

  /** Pasos de verificacion requeridos */
  requiredSteps: KybVerificationStepType[];

  /** Tipos de documentos corporativos requeridos */
  requiredDocumentTypes: CorporateDocumentType[];

  /** Tipos de documentos corporativos opcionales */
  optionalDocumentTypes: CorporateDocumentType[];

  /** Requiere verificacion de UBOs */
  requiresUboVerification: boolean;

  /** Umbral de propiedad para requerir verificacion de UBO (ej: 25%) */
  uboThresholdPercentage: number;

  /** Requiere verificacion de representantes legales */
  requiresRepresentativeVerification: boolean;

  /** Paises soportados */
  supportedCountries: CountryCode[];

  /** Tiempo de expiracion del link (segundos) */
  linkExpirationSeconds: number;

  /** Configuracion adicional por proveedor */
  providerConfiguration: Record<VerificationProvider, Record<string, unknown>>;

  /** Estado del nivel */
  isActive: boolean;
}
```

---

## 4. Value Objects

### 4.1 Proveedor de Verificacion

```typescript
/**
 * Proveedor de Verificacion
 *
 * Identifica el servicio externo que ejecuta la verificacion.
 * Este es un campo CRITICO para trazabilidad y migraciones.
 */
enum VerificationProvider {
  /** Sumsub */
  SUMSUB = 'SUMSUB',

  /** Onfido */
  ONFIDO = 'ONFIDO',

  /** Jumio */
  JUMIO = 'JUMIO',

  /** Veriff */
  VERIFF = 'VERIFF',

  /** Trulioo */
  TRULIOO = 'TRULIOO',

  /** ComplyAdvantage */
  COMPLY_ADVANTAGE = 'COMPLY_ADVANTAGE',

  /** Verificacion manual/interna */
  MANUAL = 'MANUAL',

  /** Otro proveedor */
  OTHER = 'OTHER'
}

/**
 * Informacion del Proveedor
 *
 * Metadatos sobre el proveedor actual
 */
interface ProviderInfo {
  /** Proveedor actual */
  provider: VerificationProvider;

  /** ID del sujeto en el proveedor */
  providerSubjectId: string;

  /** Fecha de sincronizacion con el proveedor */
  lastSyncedAt: Date;

  /** Version de la API del proveedor utilizada */
  apiVersion?: string;

  /** Nivel/Plan configurado en el proveedor */
  providerLevelName?: string;

  /** Metadata especifica del proveedor */
  providerMetadata?: Record<string, unknown>;
}
```

### 4.2 Identificadores

```typescript
/**
 * Identificador de Empresa (Sujeto de Verificacion KYB)
 * Inmutable, generado por el sistema
 */
type BusinessSubjectId = Brand<string, 'BusinessSubjectId'>;

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
 * Identificador de Representante Legal
 */
type RepresentativeId = Brand<string, 'RepresentativeId'>;

/**
 * Identificador de Beneficiario Final
 */
type BeneficialOwnerId = Brand<string, 'BeneficialOwnerId'>;

/**
 * Referencia externa (ID en sistema origen)
 * Ej: companyId, merchantId de nuestra aplicacion
 */
type ExternalReferenceId = Brand<string, 'ExternalReferenceId'>;

/**
 * Codigo de pais ISO 3166-1 alpha-2
 */
type CountryCode = Brand<string, 'CountryCode'>;

// Utility type para branded types
type Brand<T, B> = T & { __brand: B };
```

### 4.3 Informacion de Empresa

```typescript
/**
 * Informacion de Empresa
 * Value Object inmutable con datos de la empresa
 */
interface CompanyInfo {
  /** Nombre legal de la empresa */
  readonly legalName: string;

  /** Nombre comercial (si difiere del legal) */
  readonly tradingName?: string;

  /** Tipo de entidad legal */
  readonly legalEntityType: LegalEntityType;

  /** Numero de registro mercantil/corporativo */
  readonly registrationNumber: string;

  /** Numero de identificacion fiscal */
  readonly taxId?: string;

  /** Pais de constitucion (ISO 3166-1 alpha-2) */
  readonly countryOfIncorporation: CountryCode;

  /** Estado/Provincia de constitucion */
  readonly stateOfIncorporation?: string;

  /** Fecha de constitucion */
  readonly incorporationDate?: Date;

  /** Direccion registrada/legal */
  readonly registeredAddress: Address;

  /** Direccion de operaciones (si difiere) */
  readonly operatingAddress?: Address;

  /** Industria/sector (codigo NAICS o similar) */
  readonly industryCode?: string;

  /** Descripcion de la industria */
  readonly industryDescription?: string;

  /** Descripcion del negocio */
  readonly businessDescription?: string;

  /** Sitio web */
  readonly website?: string;

  /** Numero de empleados (rango) */
  readonly employeeCount?: EmployeeCountRange;

  /** Ingresos anuales (rango) */
  readonly annualRevenue?: RevenueRange;
}

/**
 * Tipo de Entidad Legal
 */
enum LegalEntityType {
  /** Sociedad Anonima / Corporation */
  CORPORATION = 'CORPORATION',

  /** Sociedad de Responsabilidad Limitada / LLC */
  LLC = 'LLC',

  /** Sociedad en Comandita / Limited Partnership */
  LIMITED_PARTNERSHIP = 'LIMITED_PARTNERSHIP',

  /** Sociedad General / General Partnership */
  GENERAL_PARTNERSHIP = 'GENERAL_PARTNERSHIP',

  /** Empresa Unipersonal / Sole Proprietorship */
  SOLE_PROPRIETORSHIP = 'SOLE_PROPRIETORSHIP',

  /** Organizacion sin fines de lucro / Non-Profit */
  NON_PROFIT = 'NON_PROFIT',

  /** Fideicomiso / Trust */
  TRUST = 'TRUST',

  /** Fundacion / Foundation */
  FOUNDATION = 'FOUNDATION',

  /** Cooperativa / Cooperative */
  COOPERATIVE = 'COOPERATIVE',

  /** Sucursal de empresa extranjera */
  FOREIGN_BRANCH = 'FOREIGN_BRANCH',

  /** Empresa estatal */
  STATE_OWNED = 'STATE_OWNED',

  /** Otro */
  OTHER = 'OTHER'
}

enum EmployeeCountRange {
  RANGE_1_10 = '1-10',
  RANGE_11_50 = '11-50',
  RANGE_51_200 = '51-200',
  RANGE_201_500 = '201-500',
  RANGE_501_1000 = '501-1000',
  RANGE_1001_5000 = '1001-5000',
  RANGE_5001_PLUS = '5001+'
}

enum RevenueRange {
  RANGE_0_100K = '0-100K',
  RANGE_100K_500K = '100K-500K',
  RANGE_500K_1M = '500K-1M',
  RANGE_1M_5M = '1M-5M',
  RANGE_5M_20M = '5M-20M',
  RANGE_20M_100M = '20M-100M',
  RANGE_100M_PLUS = '100M+'
}
```

### 4.4 Informacion Personal (para Representantes y UBOs)

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
  readonly dateOfBirth: Date;

  /** Lugar de nacimiento */
  readonly placeOfBirth?: string;

  /** Genero */
  readonly gender?: Gender;

  /** Nacionalidad (ISO 3166-1 alpha-2) */
  readonly nationality: CountryCode;

  /** Nacionalidades adicionales */
  readonly additionalNationalities?: CountryCode[];

  /** Numero de identificacion fiscal personal */
  readonly personalTaxId?: string;
}

enum Gender {
  MALE = 'MALE',
  FEMALE = 'FEMALE',
  OTHER = 'OTHER',
  PREFER_NOT_TO_SAY = 'PREFER_NOT_TO_SAY'
}
```

### 4.5 Informacion de Contacto

```typescript
/**
 * Informacion de Contacto de Empresa
 */
interface BusinessContactInfo {
  /** Email corporativo principal */
  readonly primaryEmail: string;

  /** Email secundario */
  readonly secondaryEmail?: string;

  /** Telefono principal */
  readonly primaryPhone: string;

  /** Telefono secundario */
  readonly secondaryPhone?: string;

  /** Nombre de contacto principal */
  readonly primaryContactName?: string;

  /** Cargo del contacto principal */
  readonly primaryContactTitle?: string;
}

/**
 * Informacion de Contacto Personal
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

### 4.6 Documento de Identidad (para Representantes y UBOs)

```typescript
/**
 * Documento de Identidad Personal
 */
interface IdentityDocument {
  /** Identificador unico */
  id: DocumentId;

  /** Tipo de documento */
  type: IdentityDocumentType;

  /** Lado del documento */
  side?: DocumentSide;

  /** Pais emisor */
  issuingCountry: CountryCode;

  /** Numero del documento */
  documentNumber?: string;

  /** Fecha de emision */
  issuedDate?: Date;

  /** Fecha de expiracion */
  expirationDate?: Date;

  /** Estado */
  status: DocumentStatus;

  /** Datos extraidos (OCR) */
  extractedData?: ExtractedIdentityData;

  /** Resultado de validacion */
  validationResult?: DocumentValidationResult;

  /** Fecha de carga */
  uploadedAt: Date;
}

enum IdentityDocumentType {
  /** Pasaporte */
  PASSPORT = 'PASSPORT',

  /** Documento Nacional de Identidad */
  NATIONAL_ID = 'NATIONAL_ID',

  /** Licencia de Conducir */
  DRIVERS_LICENSE = 'DRIVERS_LICENSE',

  /** Permiso de Residencia */
  RESIDENCE_PERMIT = 'RESIDENCE_PERMIT',

  /** Selfie */
  SELFIE = 'SELFIE',

  /** Video Selfie (Liveness) */
  VIDEO_SELFIE = 'VIDEO_SELFIE'
}

enum DocumentSide {
  FRONT = 'FRONT',
  BACK = 'BACK',
  SINGLE = 'SINGLE'
}
```

---

## 5. Enumeraciones y Estados

### 5.1 Estado de Verificacion

```typescript
/**
 * Estado de la Solicitud de Verificacion KYB
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

  /** Esperando accion de la empresa */
  AWAITING_COMPANY_ACTION = 'AWAITING_COMPANY_ACTION',

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

### 5.2 Estado de Verificacion Individual (Representantes/UBOs)

```typescript
/**
 * Estado de verificacion de persona individual dentro del KYB
 */
enum IndividualVerificationStatus {
  /** Pendiente de verificar */
  PENDING = 'PENDING',

  /** Link de verificacion enviado */
  INVITED = 'INVITED',

  /** En proceso de verificacion */
  IN_PROGRESS = 'IN_PROGRESS',

  /** Verificacion completada - Aprobado */
  VERIFIED = 'VERIFIED',

  /** Verificacion completada - Rechazado */
  REJECTED = 'REJECTED',

  /** Verificacion no requerida */
  NOT_REQUIRED = 'NOT_REQUIRED'
}
```

### 5.3 Resultado de Verificacion

```typescript
/**
 * Resultado de la Verificacion KYB
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

### 5.4 Estado de Documento

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

### 5.5 Razones de Rechazo KYB

```typescript
/**
 * Razones de Rechazo para KYB
 * Categorias especificas para verificacion de empresas
 */
enum KybRejectionReason {
  // Problemas de Documentos Corporativos
  /** Documento corporativo ilegible o de baja calidad */
  POOR_DOCUMENT_QUALITY = 'POOR_DOCUMENT_QUALITY',

  /** Documento corporativo expirado */
  DOCUMENT_EXPIRED = 'DOCUMENT_EXPIRED',

  /** Documento no valido o no soportado */
  INVALID_DOCUMENT = 'INVALID_DOCUMENT',

  /** Documento alterado o falsificado */
  DOCUMENT_FORGERY = 'DOCUMENT_FORGERY',

  /** Falta documento requerido */
  MISSING_REQUIRED_DOCUMENT = 'MISSING_REQUIRED_DOCUMENT',

  /** Documento incompleto */
  INCOMPLETE_DOCUMENT = 'INCOMPLETE_DOCUMENT',

  // Problemas de Datos de Empresa
  /** Datos de empresa no coinciden */
  COMPANY_DATA_MISMATCH = 'COMPANY_DATA_MISMATCH',

  /** Empresa no encontrada en registros oficiales */
  COMPANY_NOT_FOUND = 'COMPANY_NOT_FOUND',

  /** Empresa inactiva o disuelta */
  COMPANY_INACTIVE = 'COMPANY_INACTIVE',

  /** Informacion de registro inconsistente */
  REGISTRATION_MISMATCH = 'REGISTRATION_MISMATCH',

  // Problemas de Estructura de Propiedad
  /** Estructura de propiedad no clara */
  UNCLEAR_OWNERSHIP_STRUCTURE = 'UNCLEAR_OWNERSHIP_STRUCTURE',

  /** UBOs no identificados */
  UBOS_NOT_IDENTIFIED = 'UBOS_NOT_IDENTIFIED',

  /** Informacion de UBO incorrecta */
  UBO_INFO_MISMATCH = 'UBO_INFO_MISMATCH',

  // Problemas de Representantes Legales
  /** Representante legal no autorizado */
  UNAUTHORIZED_REPRESENTATIVE = 'UNAUTHORIZED_REPRESENTATIVE',

  /** Documento de identidad de representante rechazado */
  REPRESENTATIVE_ID_REJECTED = 'REPRESENTATIVE_ID_REJECTED',

  /** Fallo en verificacion de representante */
  REPRESENTATIVE_VERIFICATION_FAILED = 'REPRESENTATIVE_VERIFICATION_FAILED',

  // Problemas de Compliance
  /** Empresa en lista de sanciones */
  COMPANY_SANCTIONS_MATCH = 'COMPANY_SANCTIONS_MATCH',

  /** UBO en lista de sanciones */
  UBO_SANCTIONS_MATCH = 'UBO_SANCTIONS_MATCH',

  /** UBO es PEP y requiere revision adicional */
  UBO_PEP_MATCH = 'UBO_PEP_MATCH',

  /** Media adversa sobre la empresa */
  COMPANY_ADVERSE_MEDIA = 'COMPANY_ADVERSE_MEDIA',

  /** Media adversa sobre UBO */
  UBO_ADVERSE_MEDIA = 'UBO_ADVERSE_MEDIA',

  /** Industria de alto riesgo */
  HIGH_RISK_INDUSTRY = 'HIGH_RISK_INDUSTRY',

  /** Pais de alto riesgo */
  HIGH_RISK_COUNTRY = 'HIGH_RISK_COUNTRY',

  // Problemas de Verificacion de Identidad (Representantes/UBOs)
  /** Selfie no coincide con documento */
  SELFIE_MISMATCH = 'SELFIE_MISMATCH',

  /** Fallo en verificacion de vida (liveness) */
  LIVENESS_FAILED = 'LIVENESS_FAILED',

  /** Sospecha de identidad falsa */
  FRAUDULENT_IDENTITY = 'FRAUDULENT_IDENTITY',

  // Otros
  /** Empresa duplicada */
  DUPLICATE_COMPANY = 'DUPLICATE_COMPANY',

  /** Pais no soportado */
  UNSUPPORTED_COUNTRY = 'UNSUPPORTED_COUNTRY',

  /** Otro motivo */
  OTHER = 'OTHER'
}
```

### 5.6 Pasos de Verificacion KYB

```typescript
/**
 * Tipos de Pasos de Verificacion KYB
 */
enum KybVerificationStepType {
  /** Verificacion de datos basicos de empresa */
  COMPANY_DATA = 'COMPANY_DATA',

  /** Verificacion de registro mercantil */
  COMPANY_REGISTRY = 'COMPANY_REGISTRY',

  /** Verificacion de documentos corporativos */
  CORPORATE_DOCUMENTS = 'CORPORATE_DOCUMENTS',

  /** Verificacion de estructura de propiedad */
  OWNERSHIP_STRUCTURE = 'OWNERSHIP_STRUCTURE',

  /** Verificacion de beneficiarios finales (UBOs) */
  UBO_VERIFICATION = 'UBO_VERIFICATION',

  /** Verificacion de representantes legales */
  REPRESENTATIVE_VERIFICATION = 'REPRESENTATIVE_VERIFICATION',

  /** Prueba de direccion empresarial */
  BUSINESS_PROOF_OF_ADDRESS = 'BUSINESS_PROOF_OF_ADDRESS',

  /** Screening AML de empresa */
  COMPANY_AML_SCREENING = 'COMPANY_AML_SCREENING',

  /** Screening AML de UBOs */
  UBO_AML_SCREENING = 'UBO_AML_SCREENING',

  /** Verificacion de licencias regulatorias */
  REGULATORY_LICENSES = 'REGULATORY_LICENSES',

  /** Verificacion financiera */
  FINANCIAL_VERIFICATION = 'FINANCIAL_VERIFICATION'
}

/**
 * Estado de un Paso de Verificacion
 */
interface VerificationStep {
  /** Tipo de paso */
  type: KybVerificationStepType;

  /** Estado del paso */
  status: VerificationStepStatus;

  /** Resultado del paso */
  result?: StepResult;

  /** Proveedor que proceso este paso */
  processedBy?: VerificationProvider;

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

---

## 6. Interfaces y Contratos (Ports)

### 6.1 Puerto Principal: BusinessVerificationService

```typescript
/**
 * Puerto principal para servicios de verificacion KYB
 *
 * Este es el contrato que deben implementar los adaptadores
 * de proveedores externos (Sumsub, Onfido, etc.)
 */
interface IBusinessVerificationService {
  /**
   * Obtiene el proveedor actual configurado
   */
  getProvider(): VerificationProvider;

  /**
   * Crea una nueva empresa en el proveedor para verificacion
   *
   * @param command - Datos de la empresa a crear
   * @returns Empresa creada con ID del proveedor
   * @throws BusinessAlreadyExistsError si ya existe
   * @throws VerificationProviderError si hay error del proveedor
   */
  createBusiness(command: CreateBusinessCommand): Promise<BusinessVerificationSubject>;

  /**
   * Obtiene una empresa por su ID externo
   *
   * @param externalId - ID externo (de nuestro sistema)
   * @returns Empresa si existe, null si no
   */
  getBusinessByExternalId(externalId: ExternalReferenceId): Promise<BusinessVerificationSubject | null>;

  /**
   * Inicia un nuevo proceso de verificacion KYB
   *
   * @param command - Datos de la solicitud de verificacion
   * @returns Solicitud creada con URL de verificacion
   * @throws BusinessNotFoundError si la empresa no existe
   * @throws VerificationAlreadyInProgressError si ya hay una activa
   */
  initiateVerification(command: InitiateKybVerificationCommand): Promise<BusinessVerificationRequest>;

  /**
   * Obtiene el estado actual de una verificacion
   *
   * @param requestId - ID de la solicitud de verificacion
   * @returns Estado actual de la verificacion
   */
  getVerificationStatus(requestId: VerificationRequestId): Promise<BusinessVerificationRequest>;

  /**
   * Obtiene el resultado de una verificacion completada
   *
   * @param requestId - ID de la solicitud de verificacion
   * @returns Resultado detallado de la verificacion
   * @throws VerificationNotCompletedError si aun no esta completa
   */
  getVerificationResult(requestId: VerificationRequestId): Promise<BusinessVerificationResult>;

  /**
   * Agrega un representante legal a la empresa
   *
   * @param command - Datos del representante
   * @returns Representante agregado
   */
  addLegalRepresentative(command: AddRepresentativeCommand): Promise<LegalRepresentative>;

  /**
   * Agrega un beneficiario final (UBO) a la empresa
   *
   * @param command - Datos del UBO
   * @returns UBO agregado
   */
  addBeneficialOwner(command: AddUboCommand): Promise<BeneficialOwner>;

  /**
   * Genera link de verificacion para representante/UBO
   *
   * @param command - Datos para generar el link
   * @returns URL y metadata
   */
  generateIndividualVerificationLink(command: GenerateIndividualLinkCommand): Promise<IndividualVerificationLink>;

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
  retryVerification(requestId: VerificationRequestId): Promise<BusinessVerificationRequest>;
}
```

### 6.2 Puerto de URL de Verificacion

```typescript
/**
 * Puerto para generacion de URLs de verificacion KYB
 */
interface IKybVerificationUrlService {
  /**
   * Genera una URL para que la empresa complete la verificacion
   *
   * @param command - Datos para generar la URL
   * @returns URL y metadata asociada
   */
  generateBusinessVerificationUrl(command: GenerateBusinessUrlCommand): Promise<BusinessVerificationUrlResult>;

  /**
   * Genera URL para verificacion de individuo (representante/UBO)
   *
   * @param command - Datos para generar la URL
   * @returns URL y metadata
   */
  generateIndividualVerificationUrl(command: GenerateIndividualUrlCommand): Promise<IndividualVerificationUrlResult>;

  /**
   * Invalida una URL de verificacion existente
   *
   * @param requestId - ID de la solicitud asociada
   */
  invalidateUrl(requestId: VerificationRequestId): Promise<void>;
}

interface GenerateBusinessUrlCommand {
  /** ID de la empresa */
  businessId: BusinessSubjectId;

  /** Nivel de verificacion */
  levelId: VerificationLevelId;

  /** Tiempo de vida en segundos (opcional) */
  ttlSeconds?: number;

  /** URL de redireccion al completar (opcional) */
  redirectUrl?: string;

  /** Idioma de la interfaz (opcional) */
  locale?: string;
}

interface BusinessVerificationUrlResult {
  /** URL de verificacion */
  url: string;

  /** ID de la solicitud de verificacion creada */
  requestId: VerificationRequestId;

  /** Proveedor que genero la URL */
  provider: VerificationProvider;

  /** Fecha de expiracion de la URL */
  expiresAt: Date;
}

interface GenerateIndividualUrlCommand {
  /** ID del representante o UBO */
  individualId: RepresentativeId | BeneficialOwnerId;

  /** Tipo (representante o UBO) */
  individualType: 'REPRESENTATIVE' | 'UBO';

  /** ID de la solicitud de verificacion KYB padre */
  parentRequestId: VerificationRequestId;

  /** Tiempo de vida en segundos */
  ttlSeconds?: number;

  /** URL de redireccion */
  redirectUrl?: string;

  /** Idioma */
  locale?: string;
}

interface IndividualVerificationUrlResult {
  /** URL de verificacion */
  url: string;

  /** Proveedor */
  provider: VerificationProvider;

  /** Fecha de expiracion */
  expiresAt: Date;
}
```

### 6.3 Puerto de Webhooks

```typescript
/**
 * Puerto para procesamiento de notificaciones del proveedor
 */
interface IKybWebhookHandler {
  /**
   * Procesa una notificacion entrante del proveedor
   *
   * @param payload - Payload crudo del webhook
   * @param signature - Firma para validacion
   * @param provider - Proveedor origen del webhook
   * @returns Evento de dominio procesado
   * @throws InvalidWebhookSignatureError si la firma es invalida
   */
  processWebhook(payload: string, signature: string, provider: VerificationProvider): Promise<KybVerificationEvent>;

  /**
   * Valida la firma de un webhook
   *
   * @param payload - Payload crudo
   * @param signature - Firma a validar
   * @param provider - Proveedor
   * @returns true si la firma es valida
   */
  validateSignature(payload: string, signature: string, provider: VerificationProvider): boolean;
}
```

### 6.4 Puerto de Documentos Corporativos

```typescript
/**
 * Puerto para gestion de documentos corporativos
 */
interface ICorporateDocumentService {
  /**
   * Obtiene los documentos de una verificacion KYB
   *
   * @param requestId - ID de la solicitud de verificacion
   * @returns Lista de documentos
   */
  getDocuments(requestId: VerificationRequestId): Promise<CorporateDocument[]>;

  /**
   * Obtiene un documento especifico
   *
   * @param documentId - ID del documento
   * @returns Documento con datos extraidos
   */
  getDocument(documentId: DocumentId): Promise<CorporateDocument>;

  /**
   * Sube un documento corporativo
   *
   * @param command - Datos del documento a subir
   * @returns Documento creado
   */
  uploadDocument(command: UploadCorporateDocumentCommand): Promise<CorporateDocument>;

  /**
   * Obtiene la imagen/PDF de un documento
   *
   * @param documentId - ID del documento
   * @returns Datos binarios del archivo
   */
  getDocumentFile(documentId: DocumentId): Promise<DocumentFile>;
}

interface UploadCorporateDocumentCommand {
  /** ID de la solicitud de verificacion */
  requestId: VerificationRequestId;

  /** Tipo de documento */
  documentType: CorporateDocumentType;

  /** Archivo */
  file: Buffer;

  /** Tipo MIME */
  mimeType: string;

  /** Nombre del archivo */
  filename: string;

  /** Metadata adicional */
  metadata?: Record<string, unknown>;
}

interface DocumentFile {
  /** Datos binarios */
  data: Buffer;

  /** Tipo MIME */
  mimeType: string;

  /** Nombre del archivo */
  filename: string;
}
```

### 6.5 DTOs de Comandos

```typescript
/**
 * Comando para crear una empresa para verificacion
 */
interface CreateBusinessCommand {
  /** ID externo (de nuestro sistema) */
  externalId: ExternalReferenceId;

  /** Nivel de verificacion */
  levelId: VerificationLevelId;

  /** Informacion de la empresa */
  companyInfo: CompanyInfo;

  /** Informacion de contacto */
  contactInfo: BusinessContactInfo;

  /** Representantes legales iniciales */
  legalRepresentatives?: Omit<LegalRepresentative, 'id' | 'verificationStatus' | 'identityDocuments'>[];

  /** Beneficiarios finales iniciales */
  beneficialOwners?: Omit<BeneficialOwner, 'id' | 'verificationStatus' | 'identityDocuments'>[];

  /** Metadata adicional */
  metadata?: Record<string, unknown>;
}

/**
 * Comando para iniciar verificacion KYB
 */
interface InitiateKybVerificationCommand {
  /** ID de la empresa */
  businessId: BusinessSubjectId;

  /** ID externo (alternativo al businessId) */
  externalId?: ExternalReferenceId;

  /** Nivel de verificacion (opcional si ya esta definido) */
  levelId?: VerificationLevelId;

  /** Tiempo de vida de la URL en segundos */
  urlTtlSeconds?: number;

  /** URL de redireccion post-verificacion */
  redirectUrl?: string;

  /** Idioma de la interfaz */
  locale?: string;
}

/**
 * Comando para agregar representante legal
 */
interface AddRepresentativeCommand {
  /** ID de la empresa */
  businessId: BusinessSubjectId;

  /** Informacion personal */
  personalInfo: PersonalInfo;

  /** Rol */
  role: RepresentativeRole;

  /** Titulo del cargo */
  jobTitle?: string;

  /** Es el representante principal */
  isPrimary: boolean;

  /** Informacion de contacto */
  contactInfo?: ContactInfo;
}

/**
 * Comando para agregar UBO
 */
interface AddUboCommand {
  /** ID de la empresa */
  businessId: BusinessSubjectId;

  /** Informacion personal */
  personalInfo: PersonalInfo;

  /** Porcentaje de propiedad directa */
  directOwnershipPercentage: number;

  /** Porcentaje de propiedad indirecta */
  indirectOwnershipPercentage?: number;

  /** Tipo de control */
  controlType: ControlType;

  /** Descripcion de cadena de propiedad */
  ownershipChainDescription?: string;

  /** Nacionalidad */
  nationality: CountryCode;

  /** Pais de residencia */
  countryOfResidence: CountryCode;

  /** Es PEP */
  isPep: boolean;

  /** Detalles PEP */
  pepDetails?: PepDetails;

  /** Contacto */
  contactInfo?: ContactInfo;
}

/**
 * Comando para generar link individual
 */
interface GenerateIndividualLinkCommand {
  /** ID del representante o UBO */
  individualId: RepresentativeId | BeneficialOwnerId;

  /** Tipo */
  type: 'REPRESENTATIVE' | 'UBO';

  /** ID de la verificacion KYB padre */
  kybRequestId: VerificationRequestId;

  /** TTL en segundos */
  ttlSeconds?: number;

  /** URL de redireccion */
  redirectUrl?: string;

  /** Idioma */
  locale?: string;
}
```

### 6.6 DTOs de Resultados

```typescript
/**
 * Resultado completo de una verificacion KYB
 */
interface BusinessVerificationResult {
  /** ID de la solicitud */
  requestId: VerificationRequestId;

  /** Proveedor que proceso la verificacion */
  provider: VerificationProvider;

  /** Resultado general */
  outcome: VerificationOutcome;

  /** Puede reintentar (si fue rechazado) */
  canRetry: boolean;

  /** Razones de rechazo (si aplica) */
  rejectionReasons?: KybRejectionReason[];

  /** Comentario para la empresa */
  companyMessage?: string;

  /** Comentario interno */
  internalComment?: string;

  /** Resultados por paso */
  stepResults: KybStepResult[];

  /** Datos verificados de la empresa */
  verifiedCompanyData?: VerifiedCompanyData;

  /** Resultados de verificacion de representantes */
  representativeResults: RepresentativeVerificationResult[];

  /** Resultados de verificacion de UBOs */
  uboResults: UboVerificationResult[];

  /** Resultados de compliance */
  complianceResults?: KybComplianceResults;

  /** Fecha de la decision */
  decidedAt: Date;
}

/**
 * Resultado de un paso de verificacion KYB
 */
interface KybStepResult {
  /** Tipo de paso */
  stepType: KybVerificationStepType;

  /** Si paso exitosamente */
  passed: boolean;

  /** Proveedor que proceso el paso */
  processedBy: VerificationProvider;

  /** Razones de fallo (si aplica) */
  failureReasons?: KybRejectionReason[];

  /** Datos adicionales */
  data?: Record<string, unknown>;
}

/**
 * Datos verificados de la empresa
 */
interface VerifiedCompanyData {
  /** Nombre legal verificado */
  legalName: string;

  /** Numero de registro verificado */
  registrationNumber: string;

  /** Pais de constitucion */
  countryOfIncorporation: CountryCode;

  /** Fecha de constitucion */
  incorporationDate?: Date;

  /** Estado de la empresa (activa, etc.) */
  companyStatus: string;

  /** Direccion verificada */
  verifiedAddress?: Address;

  /** Documentos verificados */
  verifiedDocuments: VerifiedCorporateDocument[];
}

interface VerifiedCorporateDocument {
  /** Tipo de documento */
  type: CorporateDocumentType;

  /** Numero/referencia */
  documentReference?: string;

  /** Fecha de verificacion */
  verifiedAt: Date;
}

/**
 * Resultado de verificacion de representante
 */
interface RepresentativeVerificationResult {
  /** ID del representante */
  representativeId: RepresentativeId;

  /** Nombre */
  name: string;

  /** Rol */
  role: RepresentativeRole;

  /** Estado de verificacion */
  status: IndividualVerificationStatus;

  /** Proveedor que proceso */
  processedBy?: VerificationProvider;

  /** Razones de rechazo */
  rejectionReasons?: KybRejectionReason[];
}

/**
 * Resultado de verificacion de UBO
 */
interface UboVerificationResult {
  /** ID del UBO */
  uboId: BeneficialOwnerId;

  /** Nombre */
  name: string;

  /** Porcentaje de propiedad */
  ownershipPercentage: number;

  /** Estado de verificacion */
  status: IndividualVerificationStatus;

  /** Proveedor que proceso */
  processedBy?: VerificationProvider;

  /** Es PEP */
  isPep: boolean;

  /** Razon de rechazo */
  rejectionReasons?: KybRejectionReason[];
}

/**
 * Resultados de compliance KYB
 */
interface KybComplianceResults {
  /** Resultado de screening AML de empresa */
  companyAmlScreening?: CompanyAmlResult;

  /** Resultado de screening AML de UBOs */
  uboAmlScreening?: UboAmlResult[];

  /** Resultado de verificacion PEP */
  pepResults?: PepResult[];

  /** Resultado de verificacion de sanciones */
  sanctionsResults?: SanctionsResult;

  /** Resultado de media adversa */
  adverseMediaResults?: AdverseMediaResult;
}

interface CompanyAmlResult {
  /** Si paso el screening */
  passed: boolean;

  /** Nivel de riesgo */
  riskLevel: RiskLevel;

  /** Coincidencias encontradas */
  matches?: AmlMatch[];
}

interface UboAmlResult {
  /** ID del UBO */
  uboId: BeneficialOwnerId;

  /** Nombre */
  name: string;

  /** Si paso */
  passed: boolean;

  /** Nivel de riesgo */
  riskLevel: RiskLevel;

  /** Coincidencias */
  matches?: AmlMatch[];
}

interface AmlMatch {
  /** Nombre de la lista */
  listName: string;

  /** Tipo de coincidencia */
  matchType: string;

  /** Porcentaje de coincidencia */
  matchScore: number;

  /** Detalles */
  details?: Record<string, unknown>;
}

interface PepResult {
  /** ID del individuo (UBO) */
  individualId: BeneficialOwnerId;

  /** Nombre */
  name: string;

  /** Si es PEP */
  isPep: boolean;

  /** Nivel de PEP */
  pepLevel?: string;

  /** Detalles */
  details?: PepDetails;
}

interface SanctionsResult {
  /** Si la empresa tiene sanciones */
  companyHasSanctions: boolean;

  /** Listas donde aparece la empresa */
  companySanctionLists?: string[];

  /** UBOs con sanciones */
  ubosWithSanctions?: Array<{
    uboId: BeneficialOwnerId;
    name: string;
    sanctionLists: string[];
  }>;
}

interface AdverseMediaResult {
  /** Si se encontro media adversa */
  hasAdverseMedia: boolean;

  /** Nivel de riesgo */
  riskLevel: RiskLevel;

  /** Articulos encontrados */
  articles?: Array<{
    title: string;
    source: string;
    date: Date;
    summary?: string;
    url?: string;
  }>;
}

enum RiskLevel {
  LOW = 'LOW',
  MEDIUM = 'MEDIUM',
  HIGH = 'HIGH',
  CRITICAL = 'CRITICAL'
}
```

---

## 7. Eventos de Dominio

### 7.1 Definicion de Eventos KYB

```typescript
/**
 * Evento base de verificacion KYB
 */
interface KybVerificationEvent {
  /** ID unico del evento */
  eventId: string;

  /** Tipo de evento */
  type: KybVerificationEventType;

  /** ID de la solicitud de verificacion */
  requestId: VerificationRequestId;

  /** ID de la empresa */
  businessId: BusinessSubjectId;

  /** ID externo */
  externalId: ExternalReferenceId;

  /** Proveedor que genero el evento */
  provider: VerificationProvider;

  /** Timestamp del evento */
  occurredAt: Date;

  /** Payload especifico del evento */
  payload: KybEventPayload;
}

/**
 * Tipos de eventos de verificacion KYB
 */
enum KybVerificationEventType {
  /** Solicitud de verificacion KYB creada */
  KYB_VERIFICATION_CREATED = 'KYB_VERIFICATION_CREATED',

  /** Verificacion KYB iniciada */
  KYB_VERIFICATION_STARTED = 'KYB_VERIFICATION_STARTED',

  /** Documentos corporativos enviados */
  CORPORATE_DOCUMENTS_SUBMITTED = 'CORPORATE_DOCUMENTS_SUBMITTED',

  /** Verificacion en revision */
  KYB_VERIFICATION_IN_REVIEW = 'KYB_VERIFICATION_IN_REVIEW',

  /** Verificacion en espera */
  KYB_VERIFICATION_ON_HOLD = 'KYB_VERIFICATION_ON_HOLD',

  /** Se requiere accion de la empresa */
  COMPANY_ACTION_REQUIRED = 'COMPANY_ACTION_REQUIRED',

  /** Verificacion KYB aprobada */
  KYB_VERIFICATION_APPROVED = 'KYB_VERIFICATION_APPROVED',

  /** Verificacion KYB rechazada */
  KYB_VERIFICATION_REJECTED = 'KYB_VERIFICATION_REJECTED',

  /** Verificacion KYB expirada */
  KYB_VERIFICATION_EXPIRED = 'KYB_VERIFICATION_EXPIRED',

  /** Verificacion KYB cancelada */
  KYB_VERIFICATION_CANCELLED = 'KYB_VERIFICATION_CANCELLED',

  /** Datos de empresa actualizados */
  COMPANY_DATA_UPDATED = 'COMPANY_DATA_UPDATED',

  /** Documento corporativo procesado */
  CORPORATE_DOCUMENT_PROCESSED = 'CORPORATE_DOCUMENT_PROCESSED',

  /** Representante legal agregado */
  REPRESENTATIVE_ADDED = 'REPRESENTATIVE_ADDED',

  /** Verificacion de representante completada */
  REPRESENTATIVE_VERIFICATION_COMPLETED = 'REPRESENTATIVE_VERIFICATION_COMPLETED',

  /** UBO agregado */
  UBO_ADDED = 'UBO_ADDED',

  /** Verificacion de UBO completada */
  UBO_VERIFICATION_COMPLETED = 'UBO_VERIFICATION_COMPLETED',

  /** Paso de verificacion completado */
  KYB_STEP_COMPLETED = 'KYB_STEP_COMPLETED',

  /** Screening AML completado */
  AML_SCREENING_COMPLETED = 'AML_SCREENING_COMPLETED'
}
```

### 7.2 Payloads de Eventos KYB

```typescript
/**
 * Union type de todos los payloads de eventos KYB
 */
type KybEventPayload =
  | KybVerificationCreatedPayload
  | KybVerificationCompletedPayload
  | KybStatusChangedPayload
  | CorporateDocumentProcessedPayload
  | RepresentativeEventPayload
  | UboEventPayload
  | KybStepCompletedPayload
  | AmlScreeningCompletedPayload;

/**
 * Payload para evento de verificacion KYB creada
 */
interface KybVerificationCreatedPayload {
  type: 'KYB_VERIFICATION_CREATED';
  levelId: VerificationLevelId;
  verificationUrl?: string;
  urlExpiresAt?: Date;
  provider: VerificationProvider;
}

/**
 * Payload para verificacion KYB completada (aprobada o rechazada)
 */
interface KybVerificationCompletedPayload {
  type: 'KYB_VERIFICATION_APPROVED' | 'KYB_VERIFICATION_REJECTED';
  outcome: VerificationOutcome;
  provider: VerificationProvider;
  canRetry: boolean;
  rejectionReasons?: KybRejectionReason[];
  companyMessage?: string;
}

/**
 * Payload para cambios de estado
 */
interface KybStatusChangedPayload {
  type: 'KYB_VERIFICATION_IN_REVIEW' | 'KYB_VERIFICATION_ON_HOLD' | 'COMPANY_ACTION_REQUIRED' | 'KYB_VERIFICATION_EXPIRED' | 'KYB_VERIFICATION_CANCELLED';
  previousStatus: VerificationStatus;
  newStatus: VerificationStatus;
  provider: VerificationProvider;
  reason?: string;
}

/**
 * Payload para documento corporativo procesado
 */
interface CorporateDocumentProcessedPayload {
  type: 'CORPORATE_DOCUMENT_PROCESSED';
  documentId: DocumentId;
  documentType: CorporateDocumentType;
  status: DocumentStatus;
  provider: VerificationProvider;
  extractedData?: ExtractedCorporateData;
}

/**
 * Payload para eventos de representante
 */
interface RepresentativeEventPayload {
  type: 'REPRESENTATIVE_ADDED' | 'REPRESENTATIVE_VERIFICATION_COMPLETED';
  representativeId: RepresentativeId;
  name: string;
  role: RepresentativeRole;
  verificationStatus: IndividualVerificationStatus;
  provider?: VerificationProvider;
}

/**
 * Payload para eventos de UBO
 */
interface UboEventPayload {
  type: 'UBO_ADDED' | 'UBO_VERIFICATION_COMPLETED';
  uboId: BeneficialOwnerId;
  name: string;
  ownershipPercentage: number;
  verificationStatus: IndividualVerificationStatus;
  isPep: boolean;
  provider?: VerificationProvider;
}

/**
 * Payload para paso completado
 */
interface KybStepCompletedPayload {
  type: 'KYB_STEP_COMPLETED';
  stepType: KybVerificationStepType;
  success: boolean;
  provider: VerificationProvider;
  result?: StepResult;
}

/**
 * Payload para screening AML completado
 */
interface AmlScreeningCompletedPayload {
  type: 'AML_SCREENING_COMPLETED';
  screeningType: 'COMPANY' | 'UBOS';
  provider: VerificationProvider;
  passed: boolean;
  riskLevel: RiskLevel;
  matchesFound: number;
}
```

### 7.3 Event Handler Interface

```typescript
/**
 * Interface para handlers de eventos de verificacion KYB
 */
interface IKybVerificationEventHandler {
  /**
   * Maneja un evento de verificacion KYB
   *
   * @param event - Evento a procesar
   */
  handle(event: KybVerificationEvent): Promise<void>;
}

/**
 * Interface para publicar eventos de verificacion KYB
 */
interface IKybVerificationEventPublisher {
  /**
   * Publica un evento de verificacion KYB
   *
   * @param event - Evento a publicar
   */
  publish(event: KybVerificationEvent): Promise<void>;

  /**
   * Suscribe un handler a un tipo de evento
   *
   * @param eventType - Tipo de evento
   * @param handler - Handler a ejecutar
   */
  subscribe(eventType: KybVerificationEventType, handler: IKybVerificationEventHandler): void;
}
```

---

## 8. Excepciones de Dominio

```typescript
/**
 * Excepcion base de verificacion KYB
 */
abstract class KybVerificationError extends Error {
  abstract readonly code: string;

  constructor(
    message: string,
    public readonly provider?: VerificationProvider,
    public readonly details?: Record<string, unknown>
  ) {
    super(message);
    this.name = this.constructor.name;
  }
}

/**
 * Empresa no encontrada
 */
class BusinessNotFoundError extends KybVerificationError {
  readonly code = 'BUSINESS_NOT_FOUND';

  constructor(identifier: string, provider?: VerificationProvider) {
    super(`Business not found: ${identifier}`, provider);
  }
}

/**
 * Empresa ya existe
 */
class BusinessAlreadyExistsError extends KybVerificationError {
  readonly code = 'BUSINESS_ALREADY_EXISTS';

  constructor(externalId: string, provider?: VerificationProvider) {
    super(`Business already exists with external ID: ${externalId}`, provider);
  }
}

/**
 * Solicitud de verificacion no encontrada
 */
class KybVerificationRequestNotFoundError extends KybVerificationError {
  readonly code = 'KYB_REQUEST_NOT_FOUND';

  constructor(requestId: string, provider?: VerificationProvider) {
    super(`KYB verification request not found: ${requestId}`, provider);
  }
}

/**
 * Ya hay una verificacion KYB en progreso
 */
class KybVerificationAlreadyInProgressError extends KybVerificationError {
  readonly code = 'KYB_VERIFICATION_IN_PROGRESS';

  constructor(businessId: string, activeRequestId: string, provider?: VerificationProvider) {
    super(
      `KYB verification already in progress for business ${businessId}. Active request: ${activeRequestId}`,
      provider
    );
  }
}

/**
 * La verificacion KYB ya esta completada
 */
class KybVerificationAlreadyCompletedError extends KybVerificationError {
  readonly code = 'KYB_VERIFICATION_COMPLETED';

  constructor(requestId: string, status: VerificationStatus, provider?: VerificationProvider) {
    super(`KYB verification ${requestId} is already completed with status: ${status}`, provider);
  }
}

/**
 * La verificacion KYB aun no esta completada
 */
class KybVerificationNotCompletedError extends KybVerificationError {
  readonly code = 'KYB_VERIFICATION_NOT_COMPLETED';

  constructor(requestId: string, currentStatus: VerificationStatus, provider?: VerificationProvider) {
    super(`KYB verification ${requestId} is not completed. Current status: ${currentStatus}`, provider);
  }
}

/**
 * La verificacion KYB no puede ser reintentada
 */
class KybVerificationCannotBeRetriedError extends KybVerificationError {
  readonly code = 'KYB_CANNOT_RETRY';

  constructor(requestId: string, reason: string, provider?: VerificationProvider) {
    super(`KYB verification ${requestId} cannot be retried: ${reason}`, provider);
  }
}

/**
 * Representante legal no encontrado
 */
class RepresentativeNotFoundError extends KybVerificationError {
  readonly code = 'REPRESENTATIVE_NOT_FOUND';

  constructor(representativeId: string, provider?: VerificationProvider) {
    super(`Legal representative not found: ${representativeId}`, provider);
  }
}

/**
 * Beneficiario final no encontrado
 */
class BeneficialOwnerNotFoundError extends KybVerificationError {
  readonly code = 'UBO_NOT_FOUND';

  constructor(uboId: string, provider?: VerificationProvider) {
    super(`Beneficial owner (UBO) not found: ${uboId}`, provider);
  }
}

/**
 * Nivel de verificacion no encontrado
 */
class KybVerificationLevelNotFoundError extends KybVerificationError {
  readonly code = 'KYB_LEVEL_NOT_FOUND';

  constructor(levelId: string, provider?: VerificationProvider) {
    super(`KYB verification level not found: ${levelId}`, provider);
  }
}

/**
 * Pais no soportado para KYB
 */
class KybUnsupportedCountryError extends KybVerificationError {
  readonly code = 'KYB_UNSUPPORTED_COUNTRY';

  constructor(country: string, levelId: string, provider?: VerificationProvider) {
    super(`Country ${country} is not supported for KYB verification level ${levelId}`, provider);
  }
}

/**
 * Documento corporativo no encontrado
 */
class CorporateDocumentNotFoundError extends KybVerificationError {
  readonly code = 'CORPORATE_DOCUMENT_NOT_FOUND';

  constructor(documentId: string, provider?: VerificationProvider) {
    super(`Corporate document not found: ${documentId}`, provider);
  }
}

/**
 * Firma de webhook invalida
 */
class InvalidKybWebhookSignatureError extends KybVerificationError {
  readonly code = 'INVALID_KYB_WEBHOOK_SIGNATURE';

  constructor(provider?: VerificationProvider) {
    super('Invalid webhook signature', provider);
  }
}

/**
 * Error del proveedor de verificacion
 */
class KybVerificationProviderError extends KybVerificationError {
  readonly code = 'KYB_PROVIDER_ERROR';

  constructor(
    public readonly provider: VerificationProvider,
    public readonly providerCode: string,
    public readonly providerMessage: string,
    public readonly httpStatus?: number
  ) {
    super(`KYB provider error [${provider}]: ${providerCode} - ${providerMessage}`, provider);
  }
}

/**
 * Datos de verificacion KYB invalidos
 */
class InvalidKybDataError extends KybVerificationError {
  readonly code = 'INVALID_KYB_DATA';

  constructor(field: string, reason: string, provider?: VerificationProvider) {
    super(`Invalid KYB data for field '${field}': ${reason}`, provider);
  }
}

/**
 * Proveedor no soportado
 */
class UnsupportedProviderError extends KybVerificationError {
  readonly code = 'UNSUPPORTED_PROVIDER';

  constructor(provider: string) {
    super(`Verification provider not supported: ${provider}`);
  }
}

/**
 * Error de migracion de proveedor
 */
class ProviderMigrationError extends KybVerificationError {
  readonly code = 'PROVIDER_MIGRATION_ERROR';

  constructor(
    fromProvider: VerificationProvider,
    toProvider: VerificationProvider,
    reason: string
  ) {
    super(`Cannot migrate from ${fromProvider} to ${toProvider}: ${reason}`, toProvider);
  }
}
```

---

## 9. Mapeo Conceptual: Sumsub a Dominio

Esta seccion documenta la correspondencia entre los conceptos de Sumsub KYB y nuestro modelo de dominio interno.

### 9.1 Entidades

| Concepto Sumsub | Concepto de Dominio | Notas |
|----------------|--------------------|----|
| Applicant (type=company) | BusinessVerificationSubject | Empresa que se verifica |
| Applicant ID | BusinessSubjectId + providerSubjectId | ID interno + ID del proveedor |
| External User ID | ExternalReferenceId | Nuestro ID de empresa/merchant |
| Inspection | BusinessVerificationRequest | Proceso de verificacion KYB |
| Level | VerificationLevel | Configuracion de requisitos KYB |
| idDoc (COMPANY_DOC) | CorporateDocument | Documento corporativo |
| Beneficial Owner | BeneficialOwner | UBO |
| Director | LegalRepresentative | Representante legal |

### 9.2 Estados de Verificacion

| Sumsub reviewStatus | Dominio VerificationStatus |
|--------------------|---------------------------|
| `init` | `CREATED` |
| `pending` | `PENDING` |
| `queued` | `IN_REVIEW` |
| `onHold` | `ON_HOLD` |
| `awaitingUser` | `AWAITING_COMPANY_ACTION` |
| `completed` + GREEN | `APPROVED` |
| `completed` + RED | `REJECTED` |
| - | `EXPIRED` |
| - | `CANCELLED` |

### 9.3 Resultados de Verificacion

| Sumsub reviewAnswer | Dominio VerificationOutcome |
|--------------------|----------------------------|
| `GREEN` | `APPROVED` |
| `RED` + `RETRY` | `REJECTED_RETRY` |
| `RED` + `FINAL` | `REJECTED_FINAL` |

### 9.4 Tipos de Documento Corporativo

| Sumsub idDocSubType | Dominio CorporateDocumentType |
|---------------------|-------------------------------|
| `INCORPORATION_CERT` | `INCORPORATION_CERTIFICATE` |
| `INCORPORATION_ARTICLES` | `ARTICLES_OF_INCORPORATION` |
| `STATE_REGISTRY` | `COMMERCIAL_REGISTRY_EXTRACT` |
| `GOOD_STANDING_CERT` | `GOOD_STANDING_CERTIFICATE` |
| `POWER_OF_ATTORNEY` | `POWER_OF_ATTORNEY` |
| `SHAREHOLDER_REGISTRY` | `SHAREHOLDER_REGISTRY` |
| `DIRECTORS_REGISTRY` | `DIRECTORS_REGISTRY` |
| `REGULATORY_LICENSE` | `BUSINESS_LICENSE` |
| `PROOF_OF_ADDRESS` | `BUSINESS_PROOF_OF_ADDRESS` |
| `TAX_CERT` | `TAX_ID_CERTIFICATE` |

### 9.5 Razones de Rechazo KYB

| Sumsub rejectLabel | Dominio KybRejectionReason |
|-------------------|----------------------------|
| `UNSATISFACTORY_PHOTOS` | `POOR_DOCUMENT_QUALITY` |
| `DOCUMENT_EXPIRED` | `DOCUMENT_EXPIRED` |
| `NOT_DOCUMENT` | `INVALID_DOCUMENT` |
| `FORGERY` | `DOCUMENT_FORGERY` |
| `COMPANY_NOT_DEFINED_ACTIVITY` | `COMPANY_DATA_MISMATCH` |
| `COMPANY_NOT_DEFINED_STRUCTURE` | `UNCLEAR_OWNERSHIP_STRUCTURE` |
| `COMPANY_NOT_VALIDATED_ENTITY` | `COMPANY_NOT_FOUND` |
| `COMPANY_NOT_VALIDATED_OWNERS` | `UBOS_NOT_IDENTIFIED` |
| `SANCTIONS` | `COMPANY_SANCTIONS_MATCH` / `UBO_SANCTIONS_MATCH` |
| `PEP` | `UBO_PEP_MATCH` |
| `ADVERSE_MEDIA` | `COMPANY_ADVERSE_MEDIA` / `UBO_ADVERSE_MEDIA` |
| `DUPLICATE` | `DUPLICATE_COMPANY` |
| `WRONG_USER_REGION` | `UNSUPPORTED_COUNTRY` |

### 9.6 Tipos de Webhook KYB

| Sumsub Webhook Type | Dominio KybVerificationEventType |
|--------------------|----------------------------------|
| `applicantCreated` | `KYB_VERIFICATION_CREATED` |
| `applicantPending` | `CORPORATE_DOCUMENTS_SUBMITTED` |
| `applicantReviewed` (GREEN) | `KYB_VERIFICATION_APPROVED` |
| `applicantReviewed` (RED) | `KYB_VERIFICATION_REJECTED` |
| `applicantOnHold` | `KYB_VERIFICATION_ON_HOLD` |
| `applicantAwaitingUser` | `COMPANY_ACTION_REQUIRED` |
| `applicantPersonalInfoChanged` | `COMPANY_DATA_UPDATED` |
| `applicantReset` | `KYB_VERIFICATION_CANCELLED` |

---

## 10. Diagramas

### 10.1 Diagrama de Entidades KYB

```
+--------------------------------+
|  BusinessVerificationSubject   |
+--------------------------------+
| - id                           |
| - externalId                   |
| - provider                     | <-- NUEVO: Proveedor actual
| - providerSubjectId            | <-- NUEVO: ID en el proveedor
| - companyInfo                  |
| - legalRepresentatives[]       |
| - beneficialOwners[]           |
| - contactInfo                  |
| - verificationLevelId          |
| - verificationHistory[]        |
| - activeVerification?          |
| - metadata                     |
| - createdAt                    |
| - updatedAt                    |
+--------------------------------+
           |
           | 1:N
           v
+--------------------------------+
|  BusinessVerificationRequest   |
+--------------------------------+
| - id                           |
| - subjectId                    |
| - provider                     | <-- NUEVO: Proveedor de esta verificacion
| - providerRequestId            | <-- NUEVO: ID en el proveedor
| - verificationLevel            |
| - status                       |
| - result?                      |
| - documents[]                  |
| - representativeVerifications[]|
| - uboVerifications[]           |
| - requiredSteps[]              |
| - verificationUrl?             |
| - startedAt                    |
| - completedAt?                 |
| - updatedAt                    |
+--------------------------------+
           |
           +-- 1:N --> CorporateDocument
           |
           +-- 1:N --> LegalRepresentative
           |
           +-- 1:N --> BeneficialOwner
```

### 10.2 Diagrama de Arquitectura con Proveedores

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
                          |  - VerificationProvider (enum)
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
|  provider:        |    |                       |    |                   |
|  SUMSUB           |    |   provider:           |    |   provider:       |
|                   |    |   ONFIDO              |    |   JUMIO           |
|  implements:      |    |                       |    |                   |
|  - IBusinessVerif |    |   implements:         |    |   implements:     |
|  - IKybUrlService |    |   - IBusinessVerif    |    |   - IBusinessVerif|
|  - IKybWebhook    |    |   - ...               |    |   - ...           |
+-------------------+    +-----------------------+    +-------------------+
          |                          |                           |
          v                          v                           v
+-------------------+    +-----------------------+    +-------------------+
|   Sumsub API      |    |     Onfido API        |    |    Jumio API      |
+-------------------+    +-----------------------+    +-------------------+
```

### 10.3 Diagrama de Flujo de Verificacion KYB

```
+----------+     +----------+     +---------+     +----------+     +----------+
|  Client  |     | Backend  |     | Domain  |     | Adapter  |     | Sumsub   |
|   App    |     |   API    |     | Service |     | (Sumsub) |     |   API    |
+----+-----+     +----+-----+     +----+----+     +----+-----+     +----+-----+
     |                |                |                |                |
     | 1. Crear       |                |                |                |
     |    Empresa     |                |                |                |
     |--------------->|                |                |                |
     |                | 2. Create      |                |                |
     |                |    Business    |                |                |
     |                |--------------->|                |                |
     |                |                | 3. Create      |                |
     |                |                |    Applicant   |                |
     |                |                |--------------->|                |
     |                |                |                | 4. POST        |
     |                |                |                |    /applicants |
     |                |                |                |--------------->|
     |                |                |                |                |
     |                |                |                |<---------------|
     |                |                |                | 5. applicantId |
     |                |                |<---------------|                |
     |                |                | 6. Subject +   |                |
     |                |                |    provider +  |                |
     |                |                |    providerId  |                |
     |                |<---------------|                |                |
     |                | 7. Business    |                |                |
     |<---------------|    Created     |                |                |
     |                |                |                |                |
     | 8. Agregar UBOs|                |                |                |
     |--------------->|                |                |                |
     |                | ...            |                |                |
     |                |                |                |                |
     | 9. Iniciar     |                |                |                |
     |    Verificacion|                |                |                |
     |--------------->|                |                |                |
     |                | 10. Generate   |                |                |
     |                |     KYB URL    |                |                |
     |                |--------------->|                |                |
     |                |                | 11. Generate   |                |
     |                |                |     WebSDK Link|                |
     |                |                |--------------->|                |
     |                |                |                | 12. POST       |
     |                |                |                |     /sdklink   |
     |                |                |                |--------------->|
     |                |                |                |<---------------|
     |                |                |                | 13. URL        |
     |                |                |<---------------|                |
     |                |                | 14. Request +  |                |
     |                |                |     URL +      |                |
     |                |                |     provider   |                |
     |                |<---------------|                |                |
     |<---------------|                |                |                |
     | 15. KYB URL    |                |                |                |
     |                |                |                |                |
     | ... Empresa completa verificacion ...            |                |
     |                |                |                |                |
     |                | 16. Webhook    |                |                |
     |                |<----------------------------------------------- |
     |                |                |                |                |
     |                | 17. Process    |                |                |
     |                |     Webhook    |                |                |
     |                |--------------->|                |                |
     |                |                | 18. Transform  |                |
     |                |                |     to Domain  |                |
     |                |                |     Event      |                |
     |                |                | 19. Emit Event |                |
     |                |                |     (con       |                |
     |                |                |      provider) |                |
     |                |<---------------|                |                |
     |<---------------|                |                |                |
     | 20. KYB Result |                |                |                |
     |                |                |                |                |
```

---

## 11. Ejemplos de Implementacion

### 11.1 Factory para Crear Adaptador segun Proveedor

```typescript
// infrastructure/verification/provider-factory.ts

import { VerificationProvider } from '../../domain';
import { IBusinessVerificationService } from '../../domain/ports';
import { SumsubKybAdapter } from './sumsub/sumsub-kyb.adapter';
import { OnfidoKybAdapter } from './onfido/onfido-kyb.adapter';
import { UnsupportedProviderError } from '../../domain/exceptions';

export class KybVerificationProviderFactory {
  constructor(
    private readonly sumsubAdapter: SumsubKybAdapter,
    private readonly onfidoAdapter?: OnfidoKybAdapter,
    // ... otros adaptadores
  ) {}

  /**
   * Obtiene el adaptador para un proveedor especifico
   */
  getAdapter(provider: VerificationProvider): IBusinessVerificationService {
    switch (provider) {
      case VerificationProvider.SUMSUB:
        return this.sumsubAdapter;

      case VerificationProvider.ONFIDO:
        if (!this.onfidoAdapter) {
          throw new UnsupportedProviderError(provider);
        }
        return this.onfidoAdapter;

      default:
        throw new UnsupportedProviderError(provider);
    }
  }

  /**
   * Obtiene el proveedor por defecto configurado
   */
  getDefaultProvider(): VerificationProvider {
    // Esto vendria de configuracion
    return VerificationProvider.SUMSUB;
  }

  /**
   * Obtiene el adaptador por defecto
   */
  getDefaultAdapter(): IBusinessVerificationService {
    return this.getAdapter(this.getDefaultProvider());
  }
}
```

### 11.2 Ejemplo de Adaptador Sumsub KYB

```typescript
// infrastructure/verification/sumsub/sumsub-kyb.adapter.ts

import {
  IBusinessVerificationService,
  CreateBusinessCommand,
  BusinessVerificationSubject,
  InitiateKybVerificationCommand,
  BusinessVerificationRequest,
  VerificationProvider,
  ExternalReferenceId,
  VerificationRequestId,
  BusinessVerificationResult,
} from '../../../domain';

import { SumsubApiClient } from './sumsub-api.client';
import { SumsubKybMapper } from './sumsub-kyb.mapper';

export class SumsubKybAdapter implements IBusinessVerificationService {
  private readonly provider = VerificationProvider.SUMSUB;

  constructor(
    private readonly apiClient: SumsubApiClient,
    private readonly mapper: SumsubKybMapper,
  ) {}

  getProvider(): VerificationProvider {
    return this.provider;
  }

  async createBusiness(command: CreateBusinessCommand): Promise<BusinessVerificationSubject> {
    // Mapear de dominio a Sumsub
    const sumsubPayload = this.mapper.toSumsubCompanyApplicant(command);

    // Llamar API de Sumsub
    const response = await this.apiClient.createApplicant(sumsubPayload);

    // Mapear respuesta a dominio, incluyendo el proveedor
    return this.mapper.toBusinessVerificationSubject(response, command, this.provider);
  }

  async getBusinessByExternalId(externalId: ExternalReferenceId): Promise<BusinessVerificationSubject | null> {
    try {
      const response = await this.apiClient.getApplicantByExternalId(externalId);
      return this.mapper.toBusinessVerificationSubject(response, undefined, this.provider);
    } catch (error) {
      if (error.status === 404) {
        return null;
      }
      throw error;
    }
  }

  async initiateVerification(command: InitiateKybVerificationCommand): Promise<BusinessVerificationRequest> {
    // Generar URL de verificacion KYB
    const urlResponse = await this.apiClient.generateWebSdkLink({
      levelName: command.levelId,
      externalUserId: command.externalId || command.businessId,
      ttlInSecs: command.urlTtlSeconds,
    });

    // Mapear a dominio con proveedor
    return this.mapper.toBusinessVerificationRequest(urlResponse, command, this.provider);
  }

  async getVerificationStatus(requestId: VerificationRequestId): Promise<BusinessVerificationRequest> {
    const response = await this.apiClient.getApplicantStatus(requestId);
    return this.mapper.toBusinessVerificationRequestFromStatus(response, this.provider);
  }

  async getVerificationResult(requestId: VerificationRequestId): Promise<BusinessVerificationResult> {
    const response = await this.apiClient.getApplicantReviewResult(requestId);
    return this.mapper.toBusinessVerificationResult(response, this.provider);
  }

  // ... otros metodos
}
```

### 11.3 Ejemplo de Mapper Sumsub KYB

```typescript
// infrastructure/verification/sumsub/sumsub-kyb.mapper.ts

import {
  CreateBusinessCommand,
  BusinessVerificationSubject,
  BusinessVerificationRequest,
  BusinessVerificationResult,
  VerificationStatus,
  VerificationOutcome,
  VerificationProvider,
  KybRejectionReason,
  CorporateDocumentType,
} from '../../../domain';

export class SumsubKybMapper {
  /**
   * Mapea a sujeto de dominio incluyendo proveedor
   */
  toBusinessVerificationSubject(
    sumsubResponse: SumsubApplicantResponse,
    command?: CreateBusinessCommand,
    provider: VerificationProvider = VerificationProvider.SUMSUB
  ): BusinessVerificationSubject {
    return {
      id: generateId() as any,
      externalId: (sumsubResponse.externalUserId || command?.externalId) as any,

      // PROVEEDOR
      provider: provider,
      providerSubjectId: sumsubResponse.id,

      companyInfo: this.mapCompanyInfo(sumsubResponse.info?.companyInfo, command?.companyInfo),
      legalRepresentatives: [],
      beneficialOwners: this.mapBeneficiaries(sumsubResponse.info?.beneficiaries),
      contactInfo: this.mapContactInfo(sumsubResponse, command?.contactInfo),
      verificationLevelId: sumsubResponse.levelName as any,
      verificationHistory: [],
      activeVerification: undefined,
      metadata: sumsubResponse.metadata || {},
      createdAt: new Date(sumsubResponse.createdAt),
      updatedAt: new Date(sumsubResponse.modifiedAt || sumsubResponse.createdAt),
    };
  }

  /**
   * Mapea solicitud incluyendo proveedor
   */
  toBusinessVerificationRequest(
    urlResponse: SumsubWebSdkLinkResponse,
    command: InitiateKybVerificationCommand,
    provider: VerificationProvider
  ): BusinessVerificationRequest {
    return {
      id: generateId() as any,
      subjectId: command.businessId,

      // PROVEEDOR
      provider: provider,
      providerRequestId: urlResponse.applicantId,

      verificationLevel: {} as any, // Se llena despues
      status: VerificationStatus.CREATED,
      documents: [],
      representativeVerifications: [],
      uboVerifications: [],
      requiredSteps: [],
      verificationUrl: urlResponse.url,
      urlExpiresAt: new Date(Date.now() + (command.urlTtlSeconds || 3600) * 1000),
      startedAt: new Date(),
      updatedAt: new Date(),
    };
  }

  /**
   * Mapea resultado incluyendo proveedor
   */
  toBusinessVerificationResult(
    sumsubResult: SumsubReviewResult,
    provider: VerificationProvider
  ): BusinessVerificationResult {
    return {
      requestId: sumsubResult.applicantId as any,
      provider: provider,
      outcome: this.toVerificationOutcome(sumsubResult.reviewAnswer, sumsubResult.reviewRejectType),
      canRetry: sumsubResult.reviewRejectType !== 'FINAL',
      rejectionReasons: sumsubResult.rejectLabels
        ? this.toKybRejectionReasons(sumsubResult.rejectLabels)
        : undefined,
      companyMessage: sumsubResult.moderationComment,
      stepResults: [],
      representativeResults: [],
      uboResults: [],
      decidedAt: new Date(sumsubResult.reviewDate),
    };
  }

  /**
   * Mapea razones de rechazo de Sumsub a dominio KYB
   */
  toKybRejectionReasons(rejectLabels: string[]): KybRejectionReason[] {
    const labelMap: Record<string, KybRejectionReason> = {
      UNSATISFACTORY_PHOTOS: KybRejectionReason.POOR_DOCUMENT_QUALITY,
      DOCUMENT_EXPIRED: KybRejectionReason.DOCUMENT_EXPIRED,
      NOT_DOCUMENT: KybRejectionReason.INVALID_DOCUMENT,
      FORGERY: KybRejectionReason.DOCUMENT_FORGERY,
      COMPANY_NOT_DEFINED_ACTIVITY: KybRejectionReason.COMPANY_DATA_MISMATCH,
      COMPANY_NOT_DEFINED_STRUCTURE: KybRejectionReason.UNCLEAR_OWNERSHIP_STRUCTURE,
      COMPANY_NOT_VALIDATED_ENTITY: KybRejectionReason.COMPANY_NOT_FOUND,
      COMPANY_NOT_VALIDATED_OWNERS: KybRejectionReason.UBOS_NOT_IDENTIFIED,
      SANCTIONS: KybRejectionReason.COMPANY_SANCTIONS_MATCH,
      PEP: KybRejectionReason.UBO_PEP_MATCH,
      ADVERSE_MEDIA: KybRejectionReason.COMPANY_ADVERSE_MEDIA,
      DUPLICATE: KybRejectionReason.DUPLICATE_COMPANY,
      WRONG_USER_REGION: KybRejectionReason.UNSUPPORTED_COUNTRY,
    };

    return rejectLabels.map(label => labelMap[label] || KybRejectionReason.OTHER);
  }

  /**
   * Mapea tipos de documento corporativo
   */
  toCorporateDocumentType(sumsubDocSubType: string): CorporateDocumentType {
    const typeMap: Record<string, CorporateDocumentType> = {
      INCORPORATION_CERT: CorporateDocumentType.INCORPORATION_CERTIFICATE,
      INCORPORATION_ARTICLES: CorporateDocumentType.ARTICLES_OF_INCORPORATION,
      STATE_REGISTRY: CorporateDocumentType.COMMERCIAL_REGISTRY_EXTRACT,
      GOOD_STANDING_CERT: CorporateDocumentType.GOOD_STANDING_CERTIFICATE,
      POWER_OF_ATTORNEY: CorporateDocumentType.POWER_OF_ATTORNEY,
      SHAREHOLDER_REGISTRY: CorporateDocumentType.SHAREHOLDER_REGISTRY,
      DIRECTORS_REGISTRY: CorporateDocumentType.DIRECTORS_REGISTRY,
      REGULATORY_LICENSE: CorporateDocumentType.BUSINESS_LICENSE,
      PROOF_OF_ADDRESS: CorporateDocumentType.BUSINESS_PROOF_OF_ADDRESS,
      TAX_CERT: CorporateDocumentType.TAX_ID_CERTIFICATE,
    };

    return typeMap[sumsubDocSubType] || CorporateDocumentType.OTHER;
  }

  // ... metodos auxiliares privados
}

// Tipos internos de Sumsub (no exportados)
interface SumsubApplicantResponse {
  id: string;
  externalUserId: string;
  levelName: string;
  createdAt: string;
  modifiedAt?: string;
  info?: {
    companyInfo?: Record<string, unknown>;
    beneficiaries?: Array<Record<string, unknown>>;
  };
  metadata?: Record<string, unknown>;
}

interface SumsubWebSdkLinkResponse {
  url: string;
  applicantId: string;
}

interface SumsubReviewResult {
  applicantId: string;
  reviewAnswer: string;
  reviewRejectType?: string;
  rejectLabels?: string[];
  moderationComment?: string;
  reviewDate: string;
}
```

### 11.4 Ejemplo de Webhook Handler con Proveedor

```typescript
// infrastructure/verification/sumsub/sumsub-kyb-webhook.handler.ts

import {
  IKybWebhookHandler,
  KybVerificationEvent,
  KybVerificationEventType,
  VerificationProvider,
  InvalidKybWebhookSignatureError,
} from '../../../domain';

import { SumsubKybMapper } from './sumsub-kyb.mapper';
import * as crypto from 'crypto';

export class SumsubKybWebhookHandler implements IKybWebhookHandler {
  private readonly provider = VerificationProvider.SUMSUB;

  constructor(
    private readonly secretKey: string,
    private readonly mapper: SumsubKybMapper,
  ) {}

  validateSignature(payload: string, signature: string, provider: VerificationProvider): boolean {
    if (provider !== this.provider) {
      return false;
    }

    const expectedSignature = crypto
      .createHmac('sha256', this.secretKey)
      .update(payload)
      .digest('hex');

    return signature === expectedSignature;
  }

  async processWebhook(
    payload: string,
    signature: string,
    provider: VerificationProvider
  ): Promise<KybVerificationEvent> {
    if (!this.validateSignature(payload, signature, provider)) {
      throw new InvalidKybWebhookSignatureError(provider);
    }

    const data = JSON.parse(payload);

    return this.mapWebhookToEvent(data);
  }

  private mapWebhookToEvent(data: SumsubWebhookPayload): KybVerificationEvent {
    const eventType = this.mapWebhookType(data.type, data.reviewResult?.reviewAnswer);

    return {
      eventId: data.correlationId,
      type: eventType,
      requestId: data.applicantId as any,
      businessId: data.applicantId as any,
      externalId: data.externalUserId as any,

      // PROVEEDOR que genero el evento
      provider: this.provider,

      occurredAt: new Date(data.createdAtMs),
      payload: this.buildEventPayload(eventType, data),
    };
  }

  private mapWebhookType(
    sumsubType: string,
    reviewAnswer?: string,
  ): KybVerificationEventType {
    const typeMap: Record<string, KybVerificationEventType> = {
      applicantCreated: KybVerificationEventType.KYB_VERIFICATION_CREATED,
      applicantPending: KybVerificationEventType.CORPORATE_DOCUMENTS_SUBMITTED,
      applicantOnHold: KybVerificationEventType.KYB_VERIFICATION_ON_HOLD,
      applicantAwaitingUser: KybVerificationEventType.COMPANY_ACTION_REQUIRED,
      applicantPersonalInfoChanged: KybVerificationEventType.COMPANY_DATA_UPDATED,
      applicantReset: KybVerificationEventType.KYB_VERIFICATION_CANCELLED,
    };

    if (sumsubType === 'applicantReviewed') {
      return reviewAnswer === 'GREEN'
        ? KybVerificationEventType.KYB_VERIFICATION_APPROVED
        : KybVerificationEventType.KYB_VERIFICATION_REJECTED;
    }

    return typeMap[sumsubType] || KybVerificationEventType.KYB_VERIFICATION_CREATED;
  }

  private buildEventPayload(
    eventType: KybVerificationEventType,
    data: SumsubWebhookPayload,
  ): any {
    switch (eventType) {
      case KybVerificationEventType.KYB_VERIFICATION_APPROVED:
      case KybVerificationEventType.KYB_VERIFICATION_REJECTED:
        return {
          type: eventType,
          outcome: this.mapper.toVerificationOutcome(
            data.reviewResult?.reviewAnswer || '',
            data.reviewResult?.reviewRejectType,
          ),
          provider: this.provider,
          canRetry: data.reviewResult?.reviewRejectType !== 'FINAL',
          rejectionReasons: data.reviewResult?.rejectLabels
            ? this.mapper.toKybRejectionReasons(data.reviewResult.rejectLabels)
            : undefined,
          companyMessage: data.reviewResult?.moderationComment,
        };

      default:
        return {
          type: eventType,
          provider: this.provider,
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

### 12.1 Documentacion Oficial de Sumsub (KYB)

- [Documentacion Principal](https://docs.sumsub.com/) - Portal de documentacion de Sumsub
- [Verificacion de Empresas (KYB)](https://docs.sumsub.com/docs/business-verification) - Guia de KYB
- [API de Applicants para Empresas](https://docs.sumsub.com/reference/create-an-applicant) - Crear applicant tipo company
- [Beneficiarios Finales](https://docs.sumsub.com/docs/beneficial-owners) - Documentacion de UBOs
- [Documentos Corporativos](https://docs.sumsub.com/reference/company-document-types) - Tipos de documentos de empresa
- [Webhooks de Verificacion](https://docs.sumsub.com/docs/user-verification-webhooks) - Tipos de webhooks
- [Razones de Rechazo](https://docs.sumsub.com/reference/rejected) - Lista completa de reject labels
- [WebSDK para Empresas](https://docs.sumsub.com/docs/web-sdk-company-verification) - Integracion SDK para KYB
- [AML Screening](https://docs.sumsub.com/docs/aml-screening) - Screening AML para empresas y personas

### 12.2 Recursos de Arquitectura

- Domain-Driven Design (Eric Evans)
- Clean Architecture (Robert C. Martin)
- Hexagonal Architecture (Alistair Cockburn)
- Implementing Domain-Driven Design (Vaughn Vernon)

### 12.3 Especificaciones Relacionadas

- ISO 3166-1 - Codigos de paises
- ISO 8601 - Formato de fechas
- FATF Guidelines - Recomendaciones para KYB/AML

---

## Historial de Cambios

| Version | Fecha | Descripcion | Autor |
|---------|-------|-------------|-------|
| 1.0.0 | 2025-02-24 | Version inicial - Modelo KYB con campo provider | Arquitectura |

---

## Checklist de Validacion

- [x] Ningun modelo de dominio menciona "Sumsub" o "Applicant"
- [x] Los contratos usan solo tipos de dominio
- [x] Las entidades tienen validaciones de negocio documentadas
- [x] Los estados son comprensibles sin conocer el proveedor
- [x] **Cada entidad y evento incluye el campo `provider`**
- [x] Se pueden implementar adaptadores para otros proveedores
- [x] Enfocado exclusivamente en KYB (empresas)
- [x] Incluye UBOs y representantes legales
- [x] La documentacion incluye diagramas claros
- [x] Se incluye mapeo conceptual Sumsub -> Dominio
- [x] Se incluyen ejemplos de implementacion con provider
- [x] Referencias a documentacion oficial de Sumsub KYB
