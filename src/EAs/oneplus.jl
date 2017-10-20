export oneplus

function oneplus(ctype::DataType, nin::Int64, nout::Int64, fitness::Function;
                 record_best::Bool=false, record_fitness::Function=fitness,
                 f_mutate::Function=mutate, kwargs...)
    population = Array{ctype}(Config.oneplus_population_size)
    for i in eachindex(population)
        population[i] = ctype(nin, nout)
    end
    best = population[1]
    max_fit = -Inf
    eval_count = 0

    for generation=1:Config.oneplus_num_generations
        # evaluation
        new_best = false
        mfit = 0.0
        for p in eachindex(population)
            fit = fitness(population[p])
            eval_count += 1
            mfit += fit
            if fit >= max_fit
                best = clone(population[p])
                if fit > max_fit
                    max_fit = fit
                    new_best = true
                end
            end
        end
        mfit /= length(population)

        if new_best || ((10 * generation / Config.oneplus_num_generations) % 1 == 0.0)
            refit = max_fit
            if record_best
                refit = record_fitness(best)
            end
            Logging.info(@sprintf("R: %d %0.2f %0.2f %0.2f %d %d %0.2f %s",
                                  eval_count, max_fit, refit, mfit,
                                  sum([n.active for n in best.nodes]),
                                  length(best.nodes),
                                  mean(map(x->length(x.nodes), population)),
                                  string(f_mutate)))
            if Config.save_best
                Logging.info(@sprintf("C: %s", string(best.genes)))
            end
        end

        # selection
        for p in eachindex(population)
            population[p] = f_mutate(best)
        end
    end

    max_fit, best.genes
end
