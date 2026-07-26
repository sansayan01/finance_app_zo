import { motion } from "motion/react";

const partners = [
  "Delhi Lenders Network", "Mumbai Sahukars", "Bangalore Local Finance",
  "Pune Money Lenders", "Chennai Traders Circle", "Kolkata Sahukar Sangh",
  "Hyderabad Local Credit", "Ahmedabad Business Fund", "Jaipur Sahukars",
  "Lucknow Lenders Group",
];

export default function TrustMarquee() {
  return (
    <section className="relative py-10 md:py-12 px-6 border-t border-b border-white/[0.03] overflow-hidden bg-black/30">
      <div className="max-w-6xl mx-auto">
        <motion.p
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          viewport={{ once: true }}
          className="text-center text-white/25 text-[10px] font-medium tracking-[0.2em] uppercase mb-5"
        >
          Trusted by 10,000+ Money-Lenders Across India
        </motion.p>
        <div className="md:hidden -mx-6 px-6 overflow-x-auto scrollbar-none snap-x snap-mandatory">
          <div className="flex gap-3 w-max pb-2">
            {partners.map((name, i) => (
              <motion.span
                key={i}
                initial={{ opacity: 0, x: 20 }}
                whileInView={{ opacity: 1, x: 0 }}
                viewport={{ once: true }}
                transition={{ delay: i * 0.03, duration: 0.35 }}
                whileTap={{ scale: 0.92 }}
                whileHover={{ scale: 1.05 }}
                className="snap-start shrink-0 px-4 py-2.5 rounded-full border border-white/[0.06] bg-white/[0.01] text-white/40 hover:text-white/70 hover:border-white/[0.12] hover:bg-white/[0.03] text-sm font-medium whitespace-nowrap transition-all duration-300 cursor-default"
              >
                {name}
              </motion.span>
            ))}
          </div>
        </div>
        <div className="hidden md:block overflow-hidden">
          <div className="marquee-track flex gap-16 md:gap-24">
            {[...partners, ...partners].map((name, i) => (
              <span
                key={i}
                className="text-white/[0.15] hover:text-white/30 transition-colors duration-500 text-sm md:text-base font-medium tracking-[-0.01em] whitespace-nowrap cursor-default"
              >
                {name}
              </span>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
