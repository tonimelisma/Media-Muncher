# Media Muncher - Refactoring Opportunities

This document tracks architectural and performance debt that should be addressed in future refactoring cycles. These are not critical issues but represent opportunities to improve code quality, maintainability, and performance.

## Architectural Debt

### 4. Service Injection Pattern Incomplete

**Issue**: LogManager dependency injection is applied inconsistently.
- All services take LogManager parameter
- But pattern isn't extended to other dependencies
- Some circular dependencies between services

**Impact**:
- Difficult to test in isolation
- Tight coupling between services
- Hard to mock dependencies

**Recommendation**:
- Implement proper dependency injection container
- Define clear service interfaces
- Remove circular dependencies

## Performance Debt

### 1. Naive Thumbnail Cache Implementation

**Issue**: LRU cache uses O(n) removal (FileProcessorService.swift:320-327).
```swift
if thumbnailOrder.count > thumbnailCacheLimit, let oldestKey = thumbnailOrder.first {
    thumbnailOrder.removeFirst() // O(n) operation
    thumbnailCache.removeValue(forKey: oldestKey)
}
```

**Impact**:
- Performance degrades with cache size
- Blocking UI thread on large volumes

**Recommendation**:
- Use OrderedDictionary or implement proper LRU with O(1) operations
- Consider using NSCache for automatic memory pressure handling

### 2. Synchronous File Enumeration

**Issue**: `fastEnumerate` processes files synchronously despite being in an actor.
- Directory traversal blocks other operations
- No progress reporting during enumeration
- No cancellation support

**Impact**:
- UI freezes on large volumes
- Poor user experience
- No way to cancel long operations

**Recommendation**:
- Make enumeration truly async with yield points
- Add progress reporting
- Support cancellation via Task.checkCancellation()

### 3. Redundant File System Operations

**Issue**: Multiple `fileExists` checks in collision resolution.
- Same files checked multiple times
- No caching of file system state
- Potential TOCTOU (Time of Check Time of Use) issues

**Impact**:
- Slower import operations
- Increased disk I/O
- Potential race conditions

**Recommendation**:
- Cache file existence checks during single operation
- Batch file system operations where possible
- Use file system events for more efficient monitoring

### 4. Inefficient String Operations

**Issue**: Heavy use of NSString path manipulation.
- Multiple string conversions
- Path operations not optimized
- File extension lookups using dictionary

**Impact**:
- Unnecessary allocations
- CPU overhead on large file sets
- Memory pressure

**Recommendation**:
- Use URL path components consistently
- Cache file extension mappings
- Optimize hot path string operations

## Code Quality Debt

### 3. Missing Documentation

**Issue**: Some complex algorithms lack documentation.
- Collision resolution algorithm
- Duplicate detection heuristics
- Path building logic

**Recommendation**:
- Add comprehensive doc comments
- Document algorithm choices
- Include examples in documentation