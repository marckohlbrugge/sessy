import { Controller } from "@hotwired/stimulus"
import "chart.js"

export default class extends Controller {
  static values = {
    labels: Array,
    sent: Array,
    delivered: Array,
    bounced: Array
  }

  connect() {
    const Chart = window.Chart
    if (!Chart) return

    const isDark = window.matchMedia("(prefers-color-scheme: dark)").matches
    const gridColor = isDark ? "rgba(255,255,255,0.06)" : "rgba(0,0,0,0.04)"
    const tickColor = isDark ? "#71717a" : "#a1a1aa"

    const ctx = this.element.getContext("2d")
    this.chart = new Chart(ctx, {
      type: "line",
      data: {
        labels: this.labelsValue,
        datasets: [
          this.buildDataset("Sent", this.sentValue, "#34d399"),
          this.buildDataset("Delivered", this.deliveredValue, "#38bdf8"),
          this.buildDataset("Bounced", this.bouncedValue, "#fb7185")
        ]
      },
      options: {
        maintainAspectRatio: false,
        responsive: true,
        interaction: {
          mode: "index",
          intersect: false
        },
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: isDark ? "#27272a" : "#18181b",
            titleColor: isDark ? "#d4d4d8" : "#fafafa",
            bodyColor: isDark ? "#a1a1aa" : "#d4d4d8",
            borderColor: isDark ? "rgba(255,255,255,0.1)" : "rgba(255,255,255,0.1)",
            borderWidth: 1,
            cornerRadius: 0,
            padding: 8,
            callbacks: {
              label: (context) => `${context.dataset.label}: ${this.formatNumber(context.parsed.y)}`
            }
          }
        },
        scales: {
          x: {
            grid: { color: gridColor },
            border: { display: false },
            ticks: { color: tickColor, maxRotation: 0, font: { size: 11 } }
          },
          y: {
            beginAtZero: true,
            grid: { color: gridColor },
            border: { display: false },
            ticks: {
              color: tickColor,
              font: { size: 11 },
              callback: (value) => this.formatNumber(value)
            }
          }
        }
      }
    })
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }

  buildDataset(label, data, color) {
    return {
      label,
      data,
      borderColor: color,
      backgroundColor: "transparent",
      borderWidth: 1.5,
      pointRadius: 0,
      tension: 0
    }
  }

  formatNumber(value) {
    return new Intl.NumberFormat().format(value || 0)
  }
}
