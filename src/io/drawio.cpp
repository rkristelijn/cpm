/**
 * @file drawio.cpp
 * @brief Drawio XML file reader implementation.
 *
 * Uses a minimal hand-rolled XML parser (no external dependencies)
 * to extract nodes and edges from drawio/diagrams.net files.
 */
#include "drawio.h"

#include <cstdio>
#include <cstring>
#include <sstream>
#include <stack>

/* --- Simple XML parser utilities --- */

static std::string xml_escape(const std::string& s) {
  std::string r;
  for (char c : s) {
    if (c == '<')
      r += "&lt;";
    else if (c == '>')
      r += "&gt;";
    else if (c == '&')
      r += "&amp;";
    else if (c == '"')
      r += "&quot;";
    else
      r += c;
  }
  return r;
}

static std::string xml_unescape(const std::string& s) {
  std::string r;
  for (size_t i = 0; i < s.size(); i++) {
    if (s[i] == '&' && i + 3 < s.size() && s.substr(i, 4) == "&lt;") {
      r += '<';
      i += 3;
    } else if (s[i] == '&' && i + 3 < s.size() && s.substr(i, 4) == "&gt;") {
      r += '>';
      i += 3;
    } else if (s[i] == '&' && i + 4 < s.size() && s.substr(i, 5) == "&amp;") {
      r += '&';
      i += 4;
    } else if (s[i] == '&' && i + 5 < s.size() && s.substr(i, 6) == "&quot;") {
      r += '"';
      i += 5;
    } else {
      r += s[i];
    }
  }
  return r;
}

static std::string get_attr(const std::string& line, const std::string& attr) {
  std::string pattern = attr + "=\"";
  size_t start = line.find(pattern);
  if (start == std::string::npos) return "";
  start += pattern.size();
  size_t end = line.find("\"", start);
  if (end == std::string::npos) return "";
  return line.substr(start, end - start);
}

/* --- Drawio parsing --- */

DrawioDiagram drawio_parse(const std::string& xml) {
  DrawioDiagram diagram;
  std::istringstream stream(xml);
  std::string line;

  std::string current_parent;
  std::stack<std::string> parent_stack;

  while (std::getline(stream, line)) {
    /* Skip empty lines */
    if (line.find_first_not_of(" \t\r\n") == std::string::npos) continue;

    /* Check for mxGraphModel root */
    if (line.find("<mxGraphModel") != std::string::npos) {
      parent_stack = std::stack<std::string>();
      parent_stack.push("root");
      continue;
    }

    /* Check for root mxCell */
    if (line.find("id=\"0\"") != std::string::npos && line.find("mxCell") != std::string::npos) {
      parent_stack = std::stack<std::string>();
      parent_stack.push("0");
      continue;
    }

    /* Check for mxCell elements */
    bool is_vertex = line.find("vertex=\"1\"") != std::string::npos;
    bool is_edge = line.find("edge=\"1\"") != std::string::npos;

    if (is_vertex || is_edge) {
      std::string id = get_attr(line, "id");
      std::string value = get_attr(line, "value");
      std::string style = get_attr(line, "style");
      std::string parent = get_attr(line, "parent");

      /* Extract geometry for vertices */
      int x = 0, y = 0, w = 0, h = 0;
      if (is_vertex) {
        size_t geo_start = line.find("<mxGeometry");
        if (geo_start != std::string::npos) {
          size_t geo_end = line.find(">", geo_start);
          if (geo_end != std::string::npos) {
            std::string geo = line.substr(geo_start, geo_end - geo_start + 1);
            x = atoi(get_attr(geo, "x").c_str());
            y = atoi(get_attr(geo, "y").c_str());
            w = atoi(get_attr(geo, "width").c_str());
            h = atoi(get_attr(geo, "height").c_str());
          }
        }
      }

      /* Extract source/target for edges */
      std::string source, target;
      if (is_edge) {
        source = get_attr(line, "source");
        target = get_attr(line, "target");
      }

      /* Determine shape type from style */
      std::string shape = "rectangle";
      if (style.find("ellipse") != std::string::npos || style.find("shape=ellipse") != std::string::npos)
        shape = "ellipse";
      else if (style.find("rhombus") != std::string::npos)
        shape = "diamond";
      else if (style.find("cylinder3") != std::string::npos)
        shape = "cylinder";
      else if (style.find("swimlane") != std::string::npos)
        shape = "swimlane";
      else if (style.find("shape=umlLifeline") != std::string::npos)
        shape = "lifeline";

      if (is_vertex) {
        DrawioNode node;
        node.id = id;
        node.label = xml_unescape(value);
        node.style = style;
        node.x = x;
        node.y = y;
        node.width = w;
        node.height = h;
        node.shape = shape;
        diagram.nodes.push_back(node);
      } else if (is_edge) {
        DrawioEdge edge;
        edge.id = id;
        edge.source = source;
        edge.target = target;
        edge.label = xml_unescape(value);
        edge.style = style;
        diagram.edges.push_back(edge);
      }
    }
  }

  diagram.node_count = (int)diagram.nodes.size();
  diagram.edge_count = (int)diagram.edges.size();

  return diagram;
}

DrawioDiagram drawio_read(const std::string& path) {
  FILE* f = fopen(path.c_str(), "r");
  if (!f) return DrawioDiagram();

  std::string xml;
  char buf[4096];
  while (fgets(buf, sizeof(buf), f)) {
    xml += buf;
  }
  fclose(f);

  return drawio_parse(xml);
}

bool drawio_detect(const std::string& path) {
  FILE* f = fopen(path.c_str(), "r");
  if (!f) return false;

  char buf[256];
  bool found = false;
  while (fgets(buf, sizeof(buf), f) && !found) {
    if (strstr(buf, "<mxGraphModel") || strstr(buf, "<mxfile") || strstr(buf, "draw.io")) {
      found = true;
    }
  }
  fclose(f);
  return found;
}

/* --- Output formatters --- */

std::string drawio_describe(const DrawioDiagram& diagram) {
  std::ostringstream out;

  out << "Drawio Diagram\n";
  out << "==============\n\n";
  out << "Nodes (" << diagram.node_count << "):\n";
  out << "------\n";

  for (const auto& node : diagram.nodes) {
    out << "  [" << node.id << "] ";
    if (!node.label.empty())
      out << "\"" << node.label << "\"";
    else
      out << "(no label)";
    out << " — " << node.shape;
    out << " @ (" << node.x << "," << node.y << ")";
    out << " [" << node.width << "x" << node.height << "]\n";
  }

  out << "\nEdges (" << diagram.edge_count << "):\n";
  out << "-----\n";

  for (const auto& edge : diagram.edges) {
    out << "  [" << edge.id << "] ";
    out << edge.source << " --> " << edge.target;
    if (!edge.label.empty()) out << " : \"" << edge.label << "\"";
    out << "\n";
  }

  return out.str();
}

std::string drawio_to_mermaid(const DrawioDiagram& diagram) {
  std::ostringstream out;

  out << "flowchart TD\n";

  /* Define nodes with safe IDs */
  for (const auto& node : diagram.nodes) {
    std::string safe_id = node.id;
    /* Replace non-alphanumeric with underscore */
    for (char& c : safe_id) {
      if (!isalnum(c)) c = '_';
    }

    std::string label = node.label;
    /* Escape special mermaid characters */
    for (char& c : label) {
      if (c == '"' || c == '[' || c == ']' || c == '(' || c == ')' || c == '{' || c == '}') c = '_';
    }

    out << "    " << safe_id << "[\"" << label << "\"]\n";
  }

  out << "\n";

  /* Define edges */
  for (const auto& edge : diagram.edges) {
    std::string safe_source = edge.source;
    std::string safe_target = edge.target;
    for (char& c : safe_source) {
      if (!isalnum(c)) c = '_';
    }
    for (char& c : safe_target) {
      if (!isalnum(c)) c = '_';
    }

    out << "    " << safe_source << " --> " << safe_target;
    if (!edge.label.empty()) {
      std::string label = edge.label;
      for (char& c : label) {
        if (c == '"' || c == '[' || c == ']' || c == '(' || c == ')' || c == '{' || c == '}') c = '_';
      }
      out << " |\"" << label << "\"|";
    }
    out << "\n";
  }

  return out.str();
}

std::string drawio_to_json(const DrawioDiagram& diagram) {
  std::ostringstream out;

  out << "{\n";
  out << "  \"title\": \"" << xml_escape(diagram.title) << "\",\n";
  out << "  \"node_count\": " << diagram.node_count << ",\n";
  out << "  \"edge_count\": " << diagram.edge_count << ",\n";

  out << "  \"nodes\": [\n";
  for (size_t i = 0; i < diagram.nodes.size(); i++) {
    const auto& node = diagram.nodes[i];
    out << "    {\n";
    out << "      \"id\": \"" << xml_escape(node.id) << "\",\n";
    out << "      \"label\": \"" << xml_escape(node.label) << "\",\n";
    out << "      \"shape\": \"" << xml_escape(node.shape) << "\",\n";
    out << "      \"x\": " << node.x << ",\n";
    out << "      \"y\": " << node.y << ",\n";
    out << "      \"width\": " << node.width << ",\n";
    out << "      \"height\": " << node.height << "\n";
    out << "    }";
    if (i < diagram.nodes.size() - 1) out << ",";
    out << "\n";
  }
  out << "  ],\n";

  out << "  \"edges\": [\n";
  for (size_t i = 0; i < diagram.edges.size(); i++) {
    const auto& edge = diagram.edges[i];
    out << "    {\n";
    out << "      \"id\": \"" << xml_escape(edge.id) << "\",\n";
    out << "      \"source\": \"" << xml_escape(edge.source) << "\",\n";
    out << "      \"target\": \"" << xml_escape(edge.target) << "\",\n";
    out << "      \"label\": \"" << xml_escape(edge.label) << "\"\n";
    out << "    }";
    if (i < diagram.edges.size() - 1) out << ",";
    out << "\n";
  }
  out << "  ]\n";

  out << "}\n";

  return out.str();
}