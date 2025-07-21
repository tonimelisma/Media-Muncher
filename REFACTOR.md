# Media Muncher - Refactoring Opportunities

This document tracks architectural and performance debt that should be addressed in future refactoring cycles. These are not critical issues but represent opportunities to improve code quality, maintainability, and performance.

## Architectural Debt

### 1. Mixed Async Patterns

**Issue**: Inconsistent concurrency patterns across the codebase.
- Some files use `Task` directly (AppState.swift:191)
- Others use `AsyncThrowingStream` (ImportService.swift:65)
- Publisher chains in AppState are complex (AppState.swift:105-145)

**Impact**: 
- Harder to reason about concurrency
- Potential for subtle race conditions
- Inconsistent error handling patterns

**Recommendation**: 
- Standardize on async/await patterns
- Use actors consistently for shared mutable state
- Simplify Combine publisher chains where possible

### 2. Error Handling Inconsistency

**Issue**: Multiple error reporting mechanisms in use.
- Some places throw errors
- Others set status fields on File objects
- Others use completion handlers with error parameters
- AppError enum not used consistently

**Impact**:
- Unclear error handling contracts
- Potential for lost errors
- Difficult to debug error flows

**Recommendation**:
- Standardize error handling strategy
- Use Result types consistently
- Ensure all errors bubble up to UI appropriately

### 3. Hard-coded Constants

**Issue**: Magic numbers scattered throughout codebase.
- Thumbnail cache limit: 2000 (FileProcessorService.swift:12)
- Timestamp proximity: 60 seconds (FileProcessorService.swift:222)
- Grid column width: 120px (MediaFilesGridView.swift:19)

**Impact**:
- Difficult to tune performance
- Unclear business logic
- Hard to maintain consistency

**Recommendation**:
- Create Constants.swift file
- Group related constants
- Document why specific values were chosen

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

### 1. Large Service Classes

**Issue**: FileProcessorService and ImportService are becoming monolithic.
- FileProcessorService: >500 lines
- Multiple responsibilities in single class
- Hard to unit test specific functionality

**Recommendation**:
- Split into focused services
- Extract thumbnail management
- Separate file discovery from processing

### 2. Complex Method Signatures

**Issue**: Some methods have too many parameters.
- `fastEnumerate` takes 5 boolean parameters
- `buildFinalDestinationUrl` has optional suffix parameter
- Hard to call correctly

**Recommendation**:
- Use configuration objects
- Create builder patterns where appropriate
- Reduce parameter counts

### 3. Missing Documentation

**Issue**: Some complex algorithms lack documentation.
- Collision resolution algorithm
- Duplicate detection heuristics
- Path building logic

**Recommendation**:
- Add comprehensive doc comments
- Document algorithm choices
- Include examples in documentation

## Priority Assessment

### High Priority (Address Next Sprint)
1. Thumbnail cache LRU implementation
2. Async file enumeration with cancellation
3. Standardize error handling patterns

### Medium Priority (Next Quarter)
1. Service dependency injection
2. Constants consolidation
3. Large class decomposition

### Low Priority (Future)
1. String operation optimization
2. File system operation batching
3. Documentation improvements

## Success Metrics

- Reduced memory usage during large imports
- Faster file enumeration on large volumes
- More consistent error handling
- Improved test coverage on refactored components
- Reduced cyclomatic complexity in large methods

---

*This document should be updated as technical debt is addressed or new debt is identified.*