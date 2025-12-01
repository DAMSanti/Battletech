"""Initial baseline - existing schema

Revision ID: 001_baseline
Revises: 
Create Date: 2025-12-01 12:00:00

This migration represents the existing database schema.
It should NOT be run on existing databases.
Use: alembic stamp 001_baseline
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '001_baseline'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """
    Create initial schema.
    
    NOTE: This migration documents the existing schema.
    For existing databases, use 'alembic stamp 001_baseline' instead.
    """
    # Users table
    op.create_table(
        'users',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('username', sa.String(50), unique=True, nullable=False),
        sa.Column('email', sa.String(255), unique=True),
        sa.Column('password_hash', sa.String(255)),
        sa.Column('display_name', sa.String(100)),
        sa.Column('auth_provider', sa.String(20), default='credentials'),
        sa.Column('provider_id', sa.String(255)),
        sa.Column('elo_rating', sa.Integer, default=1000),
        sa.Column('c_bills', sa.BigInteger, default=10000),
        sa.Column('premium_currency', sa.Integer, default=0),
        sa.Column('house', sa.String(50), default='neutral'),
        sa.Column('is_active', sa.Boolean, default=True),
        sa.Column('is_banned', sa.Boolean, default=False),
        sa.Column('is_admin', sa.Boolean, default=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('last_login', sa.DateTime(timezone=True)),
        sa.Column('updated_at', sa.DateTime(timezone=True), onupdate=sa.func.now()),
    )
    op.create_index('idx_users_username', 'users', ['username'])
    op.create_index('idx_users_email', 'users', ['email'])
    
    # Sessions table
    op.create_table(
        'sessions',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('token_hash', sa.String(255), unique=True, nullable=False),
        sa.Column('device_info', sa.String(255)),
        sa.Column('ip_address', postgresql.INET),
        sa.Column('is_active', sa.Boolean, default=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('last_used_at', sa.DateTime(timezone=True)),
    )
    op.create_index('idx_sessions_user', 'sessions', ['user_id'])
    op.create_index('idx_sessions_token', 'sessions', ['token_hash'])
    op.create_index('idx_sessions_expires', 'sessions', ['expires_at'])
    
    # Pilots table
    op.create_table(
        'pilots',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('callsign', sa.String(50)),
        sa.Column('gunnery', sa.Integer, default=4),
        sa.Column('piloting', sa.Integer, default=5),
        sa.Column('experience', sa.Integer, default=0),
        sa.Column('skills', postgresql.JSONB, default={}),
        sa.Column('is_active', sa.Boolean, default=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index('idx_pilots_user', 'pilots', ['user_id'])
    
    # Mechs table
    op.create_table(
        'mechs',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('variant_id', sa.String(50), nullable=False),
        sa.Column('name', sa.String(100)),
        sa.Column('loadout', postgresql.JSONB, default={}),
        sa.Column('customization', postgresql.JSONB, default={}),
        sa.Column('is_favorite', sa.Boolean, default=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), onupdate=sa.func.now()),
    )
    op.create_index('idx_mechs_user', 'mechs', ['user_id'])
    op.create_index('idx_mechs_variant', 'mechs', ['variant_id'])
    
    # Matches table
    op.create_table(
        'matches',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('game_mode', sa.String(20), nullable=False),
        sa.Column('status', sa.String(20), default='pending'),
        sa.Column('map_id', sa.String(50)),
        sa.Column('winner_team', sa.Integer),
        sa.Column('turn_count', sa.Integer, default=0),
        sa.Column('final_state', postgresql.JSONB),
        sa.Column('replay_data', postgresql.JSONB),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('started_at', sa.DateTime(timezone=True)),
        sa.Column('ended_at', sa.DateTime(timezone=True)),
        sa.CheckConstraint("status IN ('pending', 'in_progress', 'completed', 'cancelled', 'abandoned')", name='valid_status'),
        sa.CheckConstraint("game_mode IN ('1v1', '2v2', '4v4', 'practice')", name='valid_game_mode'),
    )
    op.create_index('idx_matches_status', 'matches', ['status'])
    op.create_index('idx_matches_created', 'matches', [sa.text('created_at DESC')])
    
    # Match Players table
    op.create_table(
        'match_players',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('match_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('matches.id', ondelete='CASCADE'), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('team', sa.Integer, nullable=False),
        sa.Column('slot', sa.Integer, default=0),
        sa.Column('result', sa.String(20)),
        sa.Column('elo_before', sa.Integer),
        sa.Column('elo_after', sa.Integer),
        sa.Column('elo_change', sa.Integer),
        sa.Column('mechs_used', postgresql.JSONB, default=[]),
        sa.Column('damage_dealt', sa.Integer, default=0),
        sa.Column('damage_taken', sa.Integer, default=0),
        sa.Column('kills', sa.Integer, default=0),
        sa.Column('deaths', sa.Integer, default=0),
        sa.Column('xp_earned', sa.Integer, default=0),
        sa.Column('c_bills_earned', sa.Integer, default=0),
    )
    op.create_index('idx_match_players_match', 'match_players', ['match_id'])
    op.create_index('idx_match_players_user', 'match_players', ['user_id'])
    
    # Transactions table
    op.create_table(
        'transactions',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('type', sa.String(50), nullable=False),
        sa.Column('currency', sa.String(20), nullable=False),
        sa.Column('amount', sa.BigInteger, nullable=False),
        sa.Column('balance_after', sa.BigInteger, nullable=False),
        sa.Column('reference_type', sa.String(50)),
        sa.Column('reference_id', postgresql.UUID(as_uuid=True)),
        sa.Column('description', sa.Text),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index('idx_transactions_user', 'transactions', ['user_id'])
    op.create_index('idx_transactions_created', 'transactions', [sa.text('created_at DESC')])
    
    # Bans table
    op.create_table(
        'bans',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('banned_by', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='SET NULL')),
        sa.Column('revoked_by', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='SET NULL')),
        sa.Column('ban_type', sa.String(20), nullable=False, default='temporary'),
        sa.Column('reason', sa.String(50), nullable=False),
        sa.Column('details', sa.Text),
        sa.Column('is_active', sa.Boolean, default=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('expires_at', sa.DateTime(timezone=True)),
        sa.Column('revoked_at', sa.DateTime(timezone=True)),
        sa.Column('revoke_reason', sa.Text),
        sa.CheckConstraint("ban_type IN ('temporary', 'permanent', 'warning')", name='valid_ban_type'),
        sa.CheckConstraint("reason IN ('cheating', 'harassment', 'hate_speech', 'inappropriate_name', 'spam', 'exploiting', 'ban_evasion', 'other')", name='valid_ban_reason'),
    )
    op.create_index('idx_bans_user', 'bans', ['user_id'])
    op.create_index('idx_bans_active', 'bans', ['is_active'])
    op.create_index('idx_bans_expires', 'bans', ['expires_at'])
    
    # Audit logs table
    op.create_table(
        'audit_logs',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True)),
        sa.Column('action', sa.String(100), nullable=False),
        sa.Column('severity', sa.String(20), default='info'),
        sa.Column('ip_address', sa.String(45)),
        sa.Column('user_agent', sa.String(500)),
        sa.Column('resource_type', sa.String(50)),
        sa.Column('resource_id', sa.String(100)),
        sa.Column('extra_data', postgresql.JSONB),
        sa.Column('success', sa.Boolean, default=True),
        sa.Column('error_message', sa.Text),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index('idx_audit_action', 'audit_logs', ['action'])
    op.create_index('idx_audit_created', 'audit_logs', [sa.text('created_at DESC')])
    op.create_index('idx_audit_user', 'audit_logs', ['user_id'])
    op.create_index('idx_audit_severity', 'audit_logs', ['severity'])
    op.create_index('idx_audit_security', 'audit_logs', ['action'], postgresql_where=sa.text("action LIKE 'security.%'"))
    op.create_index('idx_audit_failures', 'audit_logs', ['created_at'], postgresql_where=sa.text("success = false"))


def downgrade() -> None:
    """Drop all tables."""
    op.drop_table('audit_logs')
    op.drop_table('bans')
    op.drop_table('transactions')
    op.drop_table('match_players')
    op.drop_table('matches')
    op.drop_table('mechs')
    op.drop_table('pilots')
    op.drop_table('sessions')
    op.drop_table('users')
