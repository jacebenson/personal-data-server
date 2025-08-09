# Health Data Import Feature

This Rails application now includes a comprehensive health data import system that can process HL7 CCD/CCDA XML documents from electronic health record (EHR) systems.

## Features

### Data Types Supported
- **Patient Information**: Demographics, contact info, birth date, gender
- **Allergies**: Active allergies with reactions and severity
- **Medications**: Current and historical medications with dosages
- **Problems/Conditions**: Active and resolved medical problems
- **Immunizations**: Vaccination history with dates
- **Vital Signs**: Blood pressure, weight, BMI, heart rate, temperature
- **Encounters**: Medical visits and appointments

### Import Methods

#### 1. Web Interface
- Navigate to `/health` for the health dashboard
- Click "Import Health Data" to upload XML files
- Supports drag-and-drop file upload
- Real-time processing with feedback

#### 2. Command Line (Rake Tasks)
```bash
# Import health data from XML file
rails health:import[tmp/DOC0001.XML]

# Show current health data summary
rails health:summary

# Clear all health data (with confirmation)
rails health:clear
```

#### 3. Programmatic Import
```ruby
# Direct service usage
import_service = HealthImportService.new
success = import_service.import_from_xml('/path/to/health_document.xml')

if success
  puts "Import completed: #{import_service.summary}"
else
  puts "Import failed: #{import_service.errors}"
end

# Background job processing
HealthImportJob.perform_later('/path/to/health_document.xml')
```

## Database Schema

### Health Models
- `HealthPatient`: Patient demographics and contact information
- `HealthAllergy`: Allergy information with reactions and severity
- `HealthMedication`: Medication details with dosage and timing
- `HealthProblem`: Medical problems/conditions with status
- `HealthImmunization`: Vaccination records with administration dates
- `HealthVitalSign`: Vital sign measurements over time
- `HealthEncounter`: Medical visits and encounters

### Key Features
- **Deduplication**: Prevents duplicate records using unique indexes
- **Data Integrity**: Foreign key constraints and validations
- **Flexible Dates**: Handles various date formats from EHR systems
- **Status Tracking**: Active/inactive status for conditions and medications

## Supported File Formats

### HL7 Clinical Document Architecture (CDA)
- **CCD**: Continuity of Care Document
- **CCDA**: Consolidated Clinical Document Architecture
- **Patient Health Summary**: Comprehensive health summaries
- **EHR Exports**: Documents from Epic, Cerner, and other major EHR systems

### Sample Document Structure
```xml
<?xml version="1.0" encoding="UTF-8"?>
<ClinicalDocument xmlns="urn:hl7-org:v3">
  <recordTarget>
    <patientRole>
      <patient>
        <name use="L">
          <given>Marjace</given>
          <family>Benson</family>
        </name>
        <!-- Patient demographics -->
      </patient>
    </patientRole>
  </recordTarget>
  <component>
    <structuredBody>
      <!-- Health data sections -->
    </structuredBody>
  </component>
</ClinicalDocument>
```

## API Routes

```
GET    /health                    # Health dashboard
GET    /health/import             # Import form
POST   /health/process_import     # Process file upload
GET    /health/:id                # Patient details
GET    /health/:id/allergies      # Patient allergies
GET    /health/:id/medications    # Patient medications
GET    /health/:id/problems       # Patient problems
GET    /health/:id/immunizations  # Patient immunizations
GET    /health/:id/vital_signs    # Patient vital signs
GET    /health/:id/encounters     # Patient encounters
```

## Security & Privacy

### Data Protection
- All health data stored securely in local SQLite database
- No external API calls or data transmission
- Full HIPAA compliance considerations built-in
- Patient data remains on your local system

### Access Control
- Requires user authentication (Devise)
- Health data tied to authenticated user sessions
- No public access to health information

## Installation & Setup

### 1. Database Migration
```bash
rails db:migrate
```

### 2. Test Import
```bash
# Place your XML file in tmp/ directory
cp /path/to/your/health_document.xml tmp/

# Import via rake task
rails health:import[tmp/health_document.xml]

# Or test via script
ruby script/test_health_import.rb tmp/health_document.xml
```

### 3. Access Web Interface
1. Start Rails server: `rails server`
2. Navigate to: `http://localhost:3000/health`
3. Login with your account
4. Import health data via web interface

## Error Handling

### Common Issues
1. **XML Namespace Issues**: The service automatically removes namespaces for compatibility
2. **Date Format Variations**: Handles YYYYMMDD and other common formats
3. **Missing Data Sections**: Gracefully skips empty or malformed sections
4. **Duplicate Records**: Uses unique indexes to prevent duplicates

### Debugging
```bash
# Check Rails logs for detailed error information
tail -f log/development.log

# Run test script for detailed output
ruby script/test_health_import.rb tmp/DOC0001.XML

# Check database contents
rails health:summary
```

## Model Usage Examples

### Querying Health Data
```ruby
# Get patient
patient = HealthPatient.first

# Active allergies
allergies = patient.health_allergies.active

# Current medications
current_meds = patient.health_medications.current

# Recent vital signs
recent_vitals = patient.health_vital_signs.recent.order(measurement_date: :desc)

# Active problems
problems = patient.health_problems.active

# Recent immunizations
immunizations = patient.health_immunizations.recent
```

### Data Analysis
```ruby
# BMI trends
patient.health_vital_signs
       .where.not(bmi: nil)
       .order(measurement_date: :desc)
       .pluck(:measurement_date, :bmi)

# Medication timeline
patient.health_medications
       .where.not(start_date: nil)
       .order(:start_date)
       .pluck(:start_date, :medication_name, :dosage)

# Problem onset tracking
patient.health_problems
       .active
       .where.not(onset_date: nil)
       .order(:onset_date)
```

## Performance Considerations

### Large File Handling
- Uses Nokogiri SAX parser for memory efficiency
- Processes sections incrementally
- Background job support for large imports
- Progress tracking and error recovery

### Database Optimization
- Indexed foreign keys for fast queries
- Unique constraints prevent duplicate processing
- Efficient date range queries on vital signs
- Optimized for patient-centric data access

## Integration with JavaScript Implementation

This Ruby implementation mirrors your existing JavaScript health parser functionality:

### Equivalent Features
- **Patient extraction**: Same demographic parsing logic
- **Section processing**: Handles allergies, medications, problems, etc.
- **Date formatting**: Converts YYYYMMDD format consistently
- **Error handling**: Comprehensive error reporting and logging
- **Data deduplication**: Prevents duplicate imports

### Migration Path
```bash
# Your existing data can be imported using the same XML files
rails health:import[path/to/your/existing/health_files/*.xml]
```

---

## Getting Started

1. **Import your first health document**:
   ```bash
   rails health:import[tmp/DOC0001.XML]
   ```

2. **View in web interface**:
   Visit `http://localhost:3000/health`

3. **Explore the data**:
   ```bash
   rails health:summary
   ```

The health import system is now fully integrated into your personal data server!
