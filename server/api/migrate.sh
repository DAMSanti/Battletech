#!/bin/bash
# =============================================================================
# Steel Titans API - Database Migration Script
# =============================================================================
# Usage:
#   ./migrate.sh                 # Show current revision
#   ./migrate.sh upgrade         # Apply all pending migrations
#   ./migrate.sh downgrade       # Rollback one migration
#   ./migrate.sh history         # Show migration history
#   ./migrate.sh current         # Show current revision
#   ./migrate.sh stamp <rev>     # Mark database at revision (no migrations run)
#   ./migrate.sh generate <msg>  # Generate new migration (autogenerate)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Activate virtual environment if it exists
if [ -d "venv" ]; then
    source venv/bin/activate
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Steel Titans API - Database Migrations${NC}"
echo "========================================"

case "${1:-current}" in
    upgrade)
        echo -e "${YELLOW}Applying pending migrations...${NC}"
        alembic upgrade head
        echo -e "${GREEN}✅ Migrations applied successfully!${NC}"
        ;;
    downgrade)
        echo -e "${YELLOW}Rolling back one migration...${NC}"
        alembic downgrade -1
        echo -e "${GREEN}✅ Rollback complete!${NC}"
        ;;
    history)
        echo -e "${YELLOW}Migration history:${NC}"
        alembic history --verbose
        ;;
    current)
        echo -e "${YELLOW}Current revision:${NC}"
        alembic current
        ;;
    stamp)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Please provide revision ID${NC}"
            echo "Usage: ./migrate.sh stamp <revision_id>"
            exit 1
        fi
        echo -e "${YELLOW}Stamping database at revision: $2${NC}"
        alembic stamp "$2"
        echo -e "${GREEN}✅ Database stamped!${NC}"
        ;;
    generate)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Please provide migration message${NC}"
            echo "Usage: ./migrate.sh generate 'add user preferences table'"
            exit 1
        fi
        echo -e "${YELLOW}Generating new migration: $2${NC}"
        alembic revision --autogenerate -m "$2"
        echo -e "${GREEN}✅ Migration generated! Review the file before applying.${NC}"
        ;;
    heads)
        echo -e "${YELLOW}Available heads:${NC}"
        alembic heads
        ;;
    *)
        echo "Usage: ./migrate.sh [command]"
        echo ""
        echo "Commands:"
        echo "  upgrade      Apply all pending migrations"
        echo "  downgrade    Rollback one migration"
        echo "  history      Show migration history"
        echo "  current      Show current database revision"
        echo "  stamp <rev>  Mark database at revision (without running migrations)"
        echo "  generate     Generate new migration with autogenerate"
        echo "  heads        Show available migration heads"
        ;;
esac
