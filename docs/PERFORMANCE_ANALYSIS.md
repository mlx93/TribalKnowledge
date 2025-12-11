# Documenter Performance Analysis

## What Takes Time in the Documenter

The documenter processes work units (domains) sequentially, and within each work unit, processes tables sequentially. For each table, it performs several time-consuming operations.

### Time Breakdown Per Table

For a typical table with **N columns**, here's what happens:

#### 1. Database Metadata Extraction (~0.1-0.5 seconds)
- Connects to database (reused connection)
- Queries table metadata (columns, keys, constraints)
- **Fast** - usually < 0.5 seconds

#### 2. Data Sampling (~0.1-5 seconds)
- Executes `SELECT * FROM table LIMIT 100`
- **5-second timeout** configured
- Can be slow for large tables or complex schemas
- **Typical**: 0.1-1 second for small tables
- **Slow**: 1-5 seconds for large/complex tables

#### 3. Column Descriptions (N × LLM calls) - **BIGGEST BOTTLENECK**
- **One LLM call per column** (sequential, not parallel)
- Each call uses **Claude Sonnet 4.5 via OpenRouter**
- **Per-column timing**:
  - API latency: 0.5-3 seconds
  - Processing time: 0.5-2 seconds
  - **Total per column: 1-5 seconds**
- **Retry logic**: Up to 3 attempts with exponential backoff (1s, 2s, 4s)
- **Timeout**: 30 seconds per call (default)
- **For 10 columns**: 10-50 seconds total (sequential)

#### 4. Table Description (1 × LLM call)
- **One LLM call per table**
- Uses **Claude Sonnet 4.5 via OpenRouter**
- **Timing**: 1-5 seconds (similar to column calls)
- Includes retry logic (up to 3 attempts)

#### 5. File Generation (~0.01-0.1 seconds)
- Generates Markdown file
- Generates JSON Schema file
- Writes to disk
- **Very fast** - negligible

### Total Time Per Table

**Formula**: 
```
Time = Metadata + Sampling + (N × Column_LLM) + Table_LLM + File_Generation
```

**Example for table with 10 columns**:
- Metadata: 0.2s
- Sampling: 0.5s
- 10 columns × 2s avg = 20s
- Table description: 2s
- File generation: 0.05s
- **Total: ~23 seconds per table**

**Example for table with 20 columns**:
- Metadata: 0.2s
- Sampling: 1s
- 20 columns × 2s avg = 40s
- Table description: 2s
- File generation: 0.05s
- **Total: ~43 seconds per table**

### Sequential Processing Impact

The documenter processes:
1. **Work units sequentially** (one domain at a time)
2. **Tables sequentially** within each work unit
3. **Columns sequentially** within each table

**No parallelism** = All time adds up linearly.

### Example: 7 Work Units, 50 Tables Total

**Assumptions**:
- Average 10 columns per table
- Average 2 seconds per LLM call
- 7 work units

**Calculation**:
- 50 tables × 23 seconds = **1,150 seconds = ~19 minutes**

**With variability**:
- Fast tables (5 columns): ~12 seconds each
- Slow tables (20 columns): ~43 seconds each
- **Realistic range: 10-25 minutes**

## Bottlenecks Ranked

### 1. LLM API Calls (90% of time)
- **Column descriptions**: One call per column, sequential
- **Table descriptions**: One call per table
- **API latency**: 0.5-3 seconds per call
- **Retries**: Can add 1-30 seconds on failures
- **No parallelism**: All calls sequential

### 2. Sequential Processing (Architectural)
- Work units processed one at a time
- Tables processed one at a time  
- Columns processed one at a time
- **Could be parallelized** but isn't currently

### 3. Database Sampling (5% of time)
- 5-second timeout per table
- Usually fast (< 1 second) but can timeout on large tables

### 4. File I/O (Negligible)
- Markdown/JSON generation and writing
- < 0.1 seconds per table

## Why It's Sequential

The current implementation processes sequentially because:

1. **Error Isolation**: If one table fails, others continue
2. **Progress Tracking**: Easier to track progress sequentially
3. **Checkpoint Recovery**: Simpler to resume from last completed table
4. **Resource Management**: Avoids overwhelming database/API with concurrent requests
5. **Token Budget**: Sequential processing makes token usage predictable

## Optimization Opportunities

### Short-term (Easy Wins)
1. **Batch column descriptions**: Group multiple columns in one LLM call
2. **Parallel column processing**: Process columns concurrently (with limit)
3. **Skip columns with existing comments**: Don't call LLM if DB comment exists

### Medium-term (Architectural)
1. **Parallel work unit processing**: Process multiple domains concurrently
2. **Parallel table processing**: Process multiple tables per work unit concurrently
3. **Smart batching**: Group related columns/tables for batch LLM calls

### Long-term (Advanced)
1. **Streaming responses**: Process columns as LLM responses arrive
2. **Caching**: Cache column descriptions for similar column names/types
3. **Incremental updates**: Only re-process changed tables/columns

## Current Performance Characteristics

| Metric | Value |
|--------|-------|
| **LLM calls per table** | N columns + 1 table = N+1 calls |
| **Average LLM call time** | 1-5 seconds |
| **Retry overhead** | +1-30 seconds on failures |
| **Sequential processing** | No parallelism |
| **Checkpoint frequency** | Every 10 tables |
| **Progress tracking** | After each table |

## Recommendations

For faster documentation:

1. **Use smaller test datasets** during development
2. **Skip columns with existing DB comments** (if implemented)
3. **Process in batches** - run documenter overnight for large schemas
4. **Monitor API rate limits** - OpenRouter may throttle if too many requests
5. **Check logs** - verify LLM calls are succeeding (not retrying excessively)

## Expected Timeline

For your current plan with **7 work units**:

- **Small tables (5 columns)**: ~12 seconds each
- **Medium tables (10 columns)**: ~23 seconds each  
- **Large tables (20 columns)**: ~43 seconds each

**Total estimate**: 10-25 minutes depending on:
- Number of tables per work unit
- Average columns per table
- LLM API response times
- Network latency
- Retry frequency

