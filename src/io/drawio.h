/**
// @see ADR-129
 * @file drawio.h
 * @brief Drawio XML file reader and visualization capability.
 *
 * Parses drawio/diagrams.net XML format and extracts:
 * - Nodes (vertices) with labels and styles
 * - Edges (connections) with source/target
 * - Layout information
 *
 * Can output:
 * - Plain text description of the diagram
 * - Mermaid flowchart format (for visualization via llama-cli)
 * - JSON structure for programmatic access
 */
#ifndef CPM_IO_DRAWIO_H
#define CPM_IO_DRAWIO_H

#include <string>
#include <vector>

/** @brief A single node in the diagram */
struct DrawioNode {
  std::string id;
  std::string label;
  std::string style;
  int x, y;
  int width, height;
  std::string shape; /* rectangle, ellipse, rhombus, cylinder3, etc. */
};

/** @brief A connection between two nodes */
struct DrawioEdge {
  std::string id;
  std::string source;
  std::string target;
  std::string label;
  std::string style;
};

/** @brief Parsed drawio diagram */
struct DrawioDiagram {
  std::string title;
  std::vector<DrawioNode> nodes;
  std::vector<DrawioEdge> edges;
  int node_count = 0;
  int edge_count = 0;
};

/**
 * @brief Parse a drawio XML file.
 * @param path Path to the .drawio or .xml file
 * @return Parsed diagram, or empty diagram on error
 */
DrawioDiagram drawio_read(const std::string& path);

/**
 * @brief Parse drawio XML from string content.
 * @param xml Raw XML content
 * @return Parsed diagram, or empty diagram on error
 */
DrawioDiagram drawio_parse(const std::string& xml);

/**
 * @brief Output diagram as mermaid flowchart format.
 * @param diagram Parsed diagram
 * @return Mermaid syntax string
 */
std::string drawio_to_mermaid(const DrawioDiagram& diagram);

/**
 * @brief Output diagram as plain text description.
 * @param diagram Parsed diagram
 * @return Human-readable description
 */
std::string drawio_describe(const DrawioDiagram& diagram);

/**
 * @brief Output diagram as JSON.
 * @param diagram Parsed diagram
 * @return JSON string
 */
std::string drawio_to_json(const DrawioDiagram& diagram);

/**
 * @brief Check if file appears to be a drawio diagram.
 * @param path File path to check
 * @return true if file contains drawio XML signature
 */
bool drawio_detect(const std::string& path);

#endif  // CPM_IO_DRAWIO_H