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
            callbacks: {
              label: (context) => `${context.dataset.label}: ${this.formatNumber(context.parsed.y)}`
            }
          }
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { color: "#6b7280", maxRotation: 0 }
          },
          y: {
            beginAtZero: true,
            ticks: {
              color: "#6b7280",
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
      borderWidth: 2,
      pointRadius: 0,
      tension: 0.35
    }
  }

  formatNumber(value) {
    return new Intl.NumberFormat().format(value || 0)
  }
}
