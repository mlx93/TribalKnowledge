#!/usr/bin/env python3
"""
ER Diagram Generator for Tribal Knowledge Database
Generates a comprehensive ER diagram showing all 340 tables across
PostgreSQL (250) and Snowflake (90) databases with FK relationships.

Output: SVG and PNG files suitable for PowerPoint presentations.
"""

import json
import sys
from pathlib import Path
from typing import Dict, List, Set, Tuple, Any
from collections import defaultdict

# Add the synthetic-250 directory to path to import domain definitions
sys.path.insert(0, str(Path(__file__).parent / "synthetic-250"))

try:
    from graphviz import Digraph
except ImportError:
    print("Error: graphviz package not installed.")
    print("Install with: pip install graphviz")
    print("Also ensure Graphviz is installed on your system:")
    print("  macOS: brew install graphviz")
    print("  Ubuntu: sudo apt-get install graphviz")
    sys.exit(1)


# Domain color palette - distinct colors for visual grouping
DOMAIN_COLORS = {
    # PostgreSQL domains
    "hr": "#E3F2FD",           # Light Blue
    "finance": "#E8F5E9",       # Light Green
    "ecommerce": "#FFF3E0",     # Light Orange
    "customers": "#FCE4EC",     # Light Pink
    "healthcare": "#F3E5F5",    # Light Purple
    "inventory": "#E0F2F1",     # Light Teal
    "orders": "#FFF8E1",        # Light Amber
    "products": "#FFEBEE",      # Light Red
    "marketing": "#E1F5FE",     # Lighter Blue
    "sales": "#F1F8E9",         # Lighter Green
    "projects": "#FBE9E7",      # Light Deep Orange
    "academic": "#EDE7F6",      # Light Deep Purple
    "education": "#E8EAF6",     # Light Indigo
    "accounting": "#E0F7FA",    # Light Cyan
    "procurement": "#F9FBE7",   # Light Lime
    "system": "#ECEFF1",        # Light Blue Grey
    "it": "#EFEBE9",            # Light Brown
    "it_infrastructure": "#FFF9C4",  # Light Yellow
    "content": "#F5F5F5",       # Light Grey
    "project_management": "#FAFAFA",  # Almost White
    
    # Snowflake domains  
    "analytics": "#B3E5FC",     # Brighter Blue
    "customer_support": "#C8E6C9",  # Brighter Green
    "content_management": "#FFE0B2",  # Brighter Orange
}

# Border colors for databases
DB_COLORS = {
    "synthetic_250_postgres": "#1565C0",    # Blue
    "synthetic_250_snowflake": "#00ACC1",   # Cyan/Teal
}


def load_domain_definitions() -> Dict[str, Dict]:
    """Load all domain definitions from the synthetic-250 scripts."""
    all_domains = {}
    
    try:
        from domains import DOMAINS
        all_domains.update(DOMAINS)
    except ImportError as e:
        print(f"Warning: Could not import domains.py: {e}")
    
    try:
        from domains_extended import DOMAINS_EXTENDED
        all_domains.update(DOMAINS_EXTENDED)
    except ImportError as e:
        print(f"Warning: Could not import domains_extended.py: {e}")
    
    try:
        from domains_more import DOMAINS_MORE
        all_domains.update(DOMAINS_MORE)
    except ImportError as e:
        print(f"Warning: Could not import domains_more.py: {e}")
    
    return all_domains


def load_documentation_plan() -> Dict:
    """Load the documentation plan to get table assignments."""
    plan_path = Path(__file__).parent.parent / "TribalAgent" / "progress" / "documentation-plan.json"
    
    if plan_path.exists():
        with open(plan_path, 'r') as f:
            return json.load(f)
    return {}


def extract_relationships_from_domains(domains: Dict) -> Tuple[Dict[str, List[str]], List[Tuple[str, str, str, str]]]:
    """
    Extract tables and FK relationships from domain definitions.
    
    Returns:
        - domain_tables: {domain_name: [table_names]}
        - relationships: [(source_table, source_col, target_table, target_col)]
    """
    domain_tables = defaultdict(list)
    relationships = []
    
    for domain_name, domain_def in domains.items():
        tables = domain_def.get("tables", [])
        
        for table in tables:
            table_name = table.get("name", "")
            if not table_name:
                continue
                
            domain_tables[domain_name].append(table_name)
            
            # Extract FK relationships
            for column in table.get("columns", []):
                fk = column.get("fk")
                if fk:
                    # FK format: "target_table.target_column"
                    parts = fk.split(".")
                    if len(parts) == 2:
                        target_table, target_column = parts
                        relationships.append((
                            table_name,
                            column.get("name", ""),
                            target_table,
                            target_column
                        ))
    
    return dict(domain_tables), relationships


def get_db_domain_mapping(plan: Dict) -> Dict[str, Dict[str, List[str]]]:
    """
    Get database -> domain -> tables mapping from documentation plan.
    
    Returns:
        {database_name: {domain_name: [table_names]}}
    """
    db_domains = defaultdict(lambda: defaultdict(list))
    
    for db in plan.get("databases", []):
        db_name = db.get("name", "")
        domains = db.get("domains", {})
        
        for domain_name, tables in domains.items():
            # Clean up table names (remove schema prefix)
            clean_tables = []
            for table in tables:
                # Handle both "SYNTHETIC.TABLE" and "synthetic.table" formats
                if "." in table:
                    clean_tables.append(table.split(".")[-1].lower())
                else:
                    clean_tables.append(table.lower())
            
            db_domains[db_name][domain_name] = clean_tables
    
    return dict(db_domains)


def create_er_diagram(
    db_domain_mapping: Dict[str, Dict[str, List[str]]],
    relationships: List[Tuple[str, str, str, str]],
    output_path: str
) -> None:
    """
    Create a comprehensive ER diagram using Graphviz.
    """
    # Create main graph
    dot = Digraph(
        name='ER_Diagram',
        comment='Tribal Knowledge Database ER Diagram',
        format='svg',
        engine='neato',  # Use neato for better large graph layout
    )
    
    # Global graph attributes for a large poster-style diagram
    dot.attr(
        rankdir='TB',
        splines='ortho',
        overlap='prism',  # Better overlap handling for large graphs
        sep='+25,25',
        nodesep='0.8',
        ranksep='1.2',
        fontname='Arial',
        fontsize='48',
        labelloc='t',
        label='Tribal Knowledge Database Schema\n340 Tables | PostgreSQL (250) + Snowflake (90)',
        bgcolor='white',
        dpi='150',
        size='60,40!',  # Large size for poster
        ratio='fill',
    )
    
    # Node defaults
    dot.attr('node',
        shape='box',
        style='filled,rounded',
        fontname='Arial',
        fontsize='10',
        width='1.5',
        height='0.4',
    )
    
    # Edge defaults
    dot.attr('edge',
        fontname='Arial',
        fontsize='8',
        color='#666666',
        arrowsize='0.5',
        penwidth='0.5',
    )
    
    # Track all tables for relationship mapping
    all_tables = {}  # table_name -> (db_name, domain_name)
    
    # Create subgraphs for each database
    for db_idx, (db_name, domains) in enumerate(db_domain_mapping.items()):
        db_color = DB_COLORS.get(db_name, "#333333")
        db_label = "PostgreSQL (250 tables)" if "postgres" in db_name else "Snowflake (90 tables)"
        
        with dot.subgraph(name=f'cluster_{db_name}') as db_cluster:
            db_cluster.attr(
                label=db_label,
                style='rounded,bold',
                color=db_color,
                penwidth='3',
                fontsize='24',
                fontcolor=db_color,
                labeljust='l',
                margin='30',
            )
            
            # Create subgraphs for each domain within the database
            for domain_idx, (domain_name, tables) in enumerate(sorted(domains.items())):
                domain_color = DOMAIN_COLORS.get(domain_name, "#F5F5F5")
                
                with db_cluster.subgraph(name=f'cluster_{db_name}_{domain_name}') as domain_cluster:
                    domain_cluster.attr(
                        label=f'{domain_name.replace("_", " ").title()} ({len(tables)})',
                        style='filled,rounded',
                        fillcolor=domain_color,
                        color='#999999',
                        penwidth='1',
                        fontsize='14',
                        margin='15',
                    )
                    
                    # Add table nodes
                    for table in sorted(tables):
                        node_id = f'{db_name}_{table}'
                        display_name = table.replace('_', '\n') if len(table) > 15 else table
                        
                        # Track for relationship mapping
                        all_tables[table.lower()] = (db_name, domain_name)
                        
                        domain_cluster.node(
                            node_id,
                            label=display_name,
                            fillcolor='white',
                            color='#333333',
                            penwidth='1',
                        )
    
    # Add relationships (edges)
    # Create a lookup for finding the correct node ID
    added_edges = set()  # Track to avoid duplicates
    
    for source_table, source_col, target_table, target_col in relationships:
        source_lower = source_table.lower()
        target_lower = target_table.lower()
        
        # Find source and target in our table mapping
        source_info = all_tables.get(source_lower)
        target_info = all_tables.get(target_lower)
        
        if source_info and target_info:
            source_node = f'{source_info[0]}_{source_lower}'
            target_node = f'{target_info[0]}_{target_lower}'
            
            edge_key = (source_node, target_node, source_col)
            if edge_key not in added_edges:
                added_edges.add(edge_key)
                
                # Determine edge style based on whether it's cross-database
                if source_info[0] != target_info[0]:
                    # Cross-database relationship
                    dot.edge(source_node, target_node,
                        color='#FF5722',
                        style='dashed',
                        penwidth='1.5',
                        constraint='false',
                    )
                else:
                    # Same database relationship
                    dot.edge(source_node, target_node,
                        color='#666666',
                        constraint='true',
                    )
    
    # Render
    try:
        # Render SVG
        dot.format = 'svg'
        svg_path = dot.render(output_path, cleanup=True)
        print(f"✓ SVG saved: {svg_path}")
        
        # Render PNG
        dot.format = 'png'
        png_path = dot.render(output_path, cleanup=True)
        print(f"✓ PNG saved: {png_path}")
        
        # Also create a simpler version using fdp for potentially better layout
        dot.engine = 'fdp'
        dot.format = 'svg'
        fdp_path = dot.render(f'{output_path}_fdp', cleanup=True)
        print(f"✓ SVG (fdp layout) saved: {fdp_path}")
        
        dot.format = 'png'
        fdp_png_path = dot.render(f'{output_path}_fdp', cleanup=True)
        print(f"✓ PNG (fdp layout) saved: {fdp_png_path}")
        
    except Exception as e:
        print(f"Error rendering diagram: {e}")
        print("Make sure Graphviz is installed: brew install graphviz")


def create_simplified_diagram(
    db_domain_mapping: Dict[str, Dict[str, List[str]]],
    relationships: List[Tuple[str, str, str, str]],
    output_path: str
) -> None:
    """
    Create a simplified ER diagram showing domains as nodes with connection counts.
    Better for PowerPoint overview slides.
    """
    dot = Digraph(
        name='ER_Diagram_Simple',
        comment='Tribal Knowledge Database - Domain Overview',
        format='svg',
        engine='dot',
    )
    
    dot.attr(
        rankdir='LR',
        splines='ortho',
        fontname='Arial',
        fontsize='32',
        labelloc='t',
        label='Tribal Knowledge Database Schema\nDomain Relationship Overview',
        bgcolor='white',
        dpi='300',
        size='24,18',
        ratio='fill',
        nodesep='1',
        ranksep='2',
    )
    
    # Create lookup for table -> domain
    table_to_domain = {}
    for db_name, domains in db_domain_mapping.items():
        for domain_name, tables in domains.items():
            for table in tables:
                table_to_domain[table.lower()] = (db_name, domain_name)
    
    # Count relationships between domains
    domain_connections = defaultdict(int)
    for source_table, _, target_table, _ in relationships:
        source_info = table_to_domain.get(source_table.lower())
        target_info = table_to_domain.get(target_table.lower())
        
        if source_info and target_info:
            source_key = f"{source_info[0]}|{source_info[1]}"
            target_key = f"{target_info[0]}|{target_info[1]}"
            
            if source_key != target_key:
                # Sort to avoid counting A->B and B->A separately
                edge_key = tuple(sorted([source_key, target_key]))
                domain_connections[edge_key] += 1
    
    # Create database subgraphs
    for db_name, domains in db_domain_mapping.items():
        db_color = DB_COLORS.get(db_name, "#333333")
        db_label = "PostgreSQL" if "postgres" in db_name else "Snowflake"
        
        with dot.subgraph(name=f'cluster_{db_name}') as db_cluster:
            db_cluster.attr(
                label=f'{db_label}',
                style='rounded,bold',
                color=db_color,
                penwidth='4',
                fontsize='28',
                fontcolor=db_color,
                margin='40',
            )
            
            for domain_name, tables in sorted(domains.items()):
                node_id = f'{db_name}|{domain_name}'
                domain_color = DOMAIN_COLORS.get(domain_name, "#F5F5F5")
                
                db_cluster.node(
                    node_id,
                    label=f'{domain_name.replace("_", " ").title()}\n({len(tables)} tables)',
                    shape='box',
                    style='filled,rounded',
                    fillcolor=domain_color,
                    color='#333333',
                    penwidth='2',
                    fontsize='16',
                    width='2.5',
                    height='0.8',
                )
    
    # Add edges between domains
    for (source_key, target_key), count in domain_connections.items():
        if count > 0:
            # Thicker lines for more connections
            penwidth = min(1 + count * 0.5, 5)
            
            dot.edge(
                source_key,
                target_key,
                label=str(count),
                color='#666666',
                penwidth=str(penwidth),
                arrowhead='none',
                fontsize='12',
            )
    
    # Render
    try:
        dot.format = 'svg'
        svg_path = dot.render(output_path, cleanup=True)
        print(f"✓ Simplified SVG saved: {svg_path}")
        
        dot.format = 'png'
        png_path = dot.render(output_path, cleanup=True)
        print(f"✓ Simplified PNG saved: {png_path}")
        
    except Exception as e:
        print(f"Error rendering simplified diagram: {e}")


def print_statistics(
    db_domain_mapping: Dict[str, Dict[str, List[str]]],
    relationships: List[Tuple[str, str, str, str]]
) -> None:
    """Print statistics about the schema."""
    print("\n" + "="*60)
    print("DATABASE SCHEMA STATISTICS")
    print("="*60)
    
    total_tables = 0
    for db_name, domains in db_domain_mapping.items():
        db_tables = sum(len(tables) for tables in domains.values())
        total_tables += db_tables
        
        db_label = "PostgreSQL" if "postgres" in db_name else "Snowflake"
        print(f"\n{db_label}: {db_tables} tables across {len(domains)} domains")
        
        for domain_name, tables in sorted(domains.items(), key=lambda x: -len(x[1])):
            print(f"  • {domain_name}: {len(tables)} tables")
    
    print(f"\nTOTAL: {total_tables} tables")
    print(f"FK Relationships: {len(relationships)}")
    print("="*60 + "\n")


def create_postgres_only_diagram(
    db_domain_mapping: Dict[str, Dict[str, List[str]]],
    relationships: List[Tuple[str, str, str, str]],
    output_path: str
) -> None:
    """
    Create an ER diagram showing only PostgreSQL tables.
    Exact same style as the full diagram, just without Snowflake.
    """
    # Filter to only PostgreSQL
    postgres_mapping = {k: v for k, v in db_domain_mapping.items() if "postgres" in k}
    
    if not postgres_mapping:
        print("No PostgreSQL database found!")
        return
    
    # Create main graph - EXACT same settings as create_er_diagram
    dot = Digraph(
        name='ER_Diagram_Postgres',
        comment='PostgreSQL Database ER Diagram',
        format='svg',
        engine='neato',
    )
    
    # Global graph attributes - EXACT same as full diagram
    dot.attr(
        rankdir='TB',
        splines='ortho',
        overlap='prism',
        sep='+25,25',
        nodesep='0.8',
        ranksep='1.2',
        fontname='Arial',
        fontsize='48',
        labelloc='t',
        label='PostgreSQL Database Schema\n250 Tables | 20 Domains',
        bgcolor='white',
        dpi='150',
        size='60,40!',
        ratio='fill',
    )
    
    # Node defaults - EXACT same as full diagram
    dot.attr('node',
        shape='box',
        style='filled,rounded',
        fontname='Arial',
        fontsize='10',
        width='1.5',
        height='0.4',
    )
    
    # Edge defaults - EXACT same as full diagram
    dot.attr('edge',
        fontname='Arial',
        fontsize='8',
        color='#666666',
        arrowsize='0.5',
        penwidth='0.5',
    )
    
    # Track all tables for relationship mapping
    all_tables = {}
    
    # Create subgraphs for PostgreSQL database - EXACT same structure as full diagram
    for db_name, domains in postgres_mapping.items():
        db_color = DB_COLORS.get(db_name, "#1565C0")
        
        with dot.subgraph(name=f'cluster_{db_name}') as db_cluster:
            db_cluster.attr(
                label='PostgreSQL (250 tables)',
                style='rounded,bold',
                color=db_color,
                penwidth='3',
                fontsize='24',
                fontcolor=db_color,
                labeljust='l',
                margin='30',
            )
            
            # Create subgraphs for each domain within the database
            for domain_idx, (domain_name, tables) in enumerate(sorted(domains.items())):
                domain_color = DOMAIN_COLORS.get(domain_name, "#F5F5F5")
                
                with db_cluster.subgraph(name=f'cluster_{db_name}_{domain_name}') as domain_cluster:
                    domain_cluster.attr(
                        label=f'{domain_name.replace("_", " ").title()} ({len(tables)})',
                        style='filled,rounded',
                        fillcolor=domain_color,
                        color='#999999',
                        penwidth='1',
                        fontsize='14',
                        margin='15',
                    )
                    
                    # Add table nodes
                    for table in sorted(tables):
                        node_id = f'{db_name}_{table}'
                        display_name = table.replace('_', '\n') if len(table) > 15 else table
                        
                        # Track for relationship mapping
                        all_tables[table.lower()] = (db_name, domain_name)
                        
                        domain_cluster.node(
                            node_id,
                            label=display_name,
                            fillcolor='white',
                            color='#333333',
                            penwidth='1',
                        )
    
    # Add relationships (edges) - EXACT same logic as full diagram
    added_edges = set()
    edge_count = 0
    
    for source_table, source_col, target_table, target_col in relationships:
        source_lower = source_table.lower()
        target_lower = target_table.lower()
        
        source_info = all_tables.get(source_lower)
        target_info = all_tables.get(target_lower)
        
        if source_info and target_info:
            source_node = f'{source_info[0]}_{source_lower}'
            target_node = f'{target_info[0]}_{target_lower}'
            
            edge_key = (source_node, target_node, source_col)
            if edge_key not in added_edges:
                added_edges.add(edge_key)
                edge_count += 1
                
                # Same database relationship styling
                dot.edge(source_node, target_node,
                    color='#666666',
                    constraint='true',
                )
    
    print(f"   Added {edge_count} relationship edges")
    
    # Render
    try:
        dot.format = 'svg'
        svg_path = dot.render(output_path, cleanup=True)
        print(f"✓ SVG saved: {svg_path}")
        
        dot.format = 'png'
        png_path = dot.render(output_path, cleanup=True)
        print(f"✓ PNG saved: {png_path}")
        
    except Exception as e:
        print(f"Error rendering diagram: {e}")


def main():
    print("="*60)
    print("Tribal Knowledge ER Diagram Generator")
    print("="*60)
    
    # Load data
    print("\n1. Loading domain definitions...")
    domains = load_domain_definitions()
    print(f"   Loaded {len(domains)} domains")
    
    print("\n2. Loading documentation plan...")
    plan = load_documentation_plan()
    print(f"   Found {len(plan.get('databases', []))} databases")
    
    print("\n3. Extracting relationships...")
    domain_tables, relationships = extract_relationships_from_domains(domains)
    print(f"   Found {len(relationships)} FK relationships")
    
    print("\n4. Building database-domain mapping...")
    db_domain_mapping = get_db_domain_mapping(plan)
    
    # Print statistics
    print_statistics(db_domain_mapping, relationships)
    
    # Output directory
    output_dir = Path(__file__).parent.parent / "docs" / "diagrams"
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Generate diagrams
    print("5. Generating detailed ER diagram (this may take a moment)...")
    create_er_diagram(
        db_domain_mapping,
        relationships,
        str(output_dir / "er_diagram_full")
    )
    
    print("\n6. Generating simplified domain overview diagram...")
    create_simplified_diagram(
        db_domain_mapping,
        relationships,
        str(output_dir / "er_diagram_domains")
    )
    
    print("\n7. Generating PostgreSQL-only diagram...")
    create_postgres_only_diagram(
        db_domain_mapping,
        relationships,
        str(output_dir / "er_diagram_postgres")
    )
    
    print("\n" + "="*60)
    print("COMPLETE!")
    print("="*60)
    print(f"\nOutput files saved to: {output_dir}")
    print("\nFor PowerPoint:")
    print("  • er_diagram_postgres.png - PostgreSQL only (250 tables)")
    print("  • er_diagram_domains.png - High-level domain overview")
    print("  • er_diagram_full.png - All databases detailed")
    print("  • SVG versions also available for vector graphics")
    print("\nTo insert into PowerPoint:")
    print("  1. Open PowerPoint")
    print("  2. Insert > Pictures > From File")
    print("  3. Select the PNG file")
    print("  4. Resize as needed")


if __name__ == "__main__":
    main()

