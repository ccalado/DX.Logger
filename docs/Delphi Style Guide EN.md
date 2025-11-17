# Delphi Style Guide

Version 2.1, updated 2025-10-08

This comprehensive style guide establishes conventions for modern Delphi projects across formatting, naming, structure, and coding practices.

## Key Formatting Rules

**Indentation & Line Length:**
- Use 2 spaces per logical block (avoid tabs)
- Maximum 120 characters per line
- `begin..end` statements on separate lines

**Comments:**
- `//` for single-line comments
- `{}` for multi-line comments
- `(* *)` for temporarily disabled code
- `///` for XML documentation

## Naming Conventions Summary

| Element | Convention | Example |
|---------|-----------|---------|
| Variables (local) | L prefix + PascalCase | `LCustomerName` |
| Variables (field) | F prefix + PascalCase | `FConnectionString` |
| Parameters | A prefix + PascalCase | `AValue` |
| Loop counters | lowercase, no prefix | `i`, `j` (exception to rules) |
| Constants | c prefix; sc for strings | `cMaxRetries`, `scErrorMsg` |
| Types/Classes | T prefix + PascalCase | `TCustomer` |
| Interfaces | I prefix + PascalCase | `ILogger` |
| Exceptions | E prefix + PascalCase | `EFileNotFound` |
| Methods | Verb + PascalCase | `SaveDocument`, `IsValidEmail` |

## Unit Organization

**Namespace Hierarchy with Dot Notation:**
- Forms: `Main.Form` → file `Main.Form.pas` → class `TFormMain`
- Data Modules: `Main.DM` → file `Main.DM.pas` → class `TDMMain`
- Nested: `Customer.Details.Form` → `TFormCustomerDetails`

## Error Handling Best Practices

Always use `FreeAndNil()` instead of `.Free`:
```delphi
try
  LObject := TObject.Create;
finally
  FreeAndNil(LObject);
end;
```

## Modern Delphi Features

- **Collections:** Use `TArray<T>` for fixed sizes, `TList<T>` for dynamic lists, `TObjectList<T>` for owned objects
- **Inline variables** (Delphi 10.3+) preferred in loops
- **Sealed classes** for utility functions
- **Generics** for type-safe collections
- **Anonymous methods** for callbacks

## Documentation

Use XML documentation comments with `///`:
```delphi
/// <summary>
/// Calculates the sum of two numbers
/// </summary>
```

This guide emphasizes consistency, maintainability, and modern Delphi practices.
